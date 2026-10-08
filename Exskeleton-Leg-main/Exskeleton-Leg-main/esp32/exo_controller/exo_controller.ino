// EXO-SLT ESP32 controller (USB Type-C / CP210x serial).
// Three external pull-up buttons, active LOW:
// GPIO13 = previous exercise
// GPIO34 = next exercise
// GPIO35 = select/start; long press = stop and return HOME
// GPIO34/GPIO35 are input-only pins, so the pull-up resistors must be
// physically installed. Do not use INPUT_PULLUP on those pins.
// OLED 0.96in SSD1306 128x64: I2C SDA=21, SCL=22, address=0x3C.
// The commissioned cylinder drivers are controlled with timed phases. The
// internal cylinder end stops provide the physical travel protection; every
// software direction change still passes through a STOP rest.
#include <Arduino.h>
#include <Wire.h>

#if __has_include(<Adafruit_GFX.h>) && __has_include(<Adafruit_SSD1306.h>)
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#define EXO_HAS_OLED 1
#else
#define EXO_HAS_OLED 0
#endif

// 100 Hz JSON IMU telemetry needs more bandwidth than 115200 baud.
static constexpr uint32_t BAUD = 921600;
#define ExoUart Serial
static constexpr uint8_t TCA9548A_ADDRESS = 0x70;
static constexpr uint8_t MPU6050_ADDRESS = 0x68;
static constexpr uint8_t MPU6050_CHANNEL = 4;
static constexpr uint32_t IMU_SAMPLE_PERIOD_MS = 10; // 100 Hz
static constexpr uint32_t IMU_CONFIG_CHECK_PERIOD_MS = 1000;
static constexpr int BUTTON_PREVIOUS = 13;
static constexpr int BUTTON_NEXT = 34;
static constexpr int BUTTON_SELECT = 35;
static constexpr int BATTERY_ADC_PIN = 14;  // D14, after 56k/10k divider
static constexpr float BATTERY_DIVIDER_RATIO = (56.0f + 10.0f) / 10.0f;
// 12V LiFePO4 (4S) profile. Voltage-only percentage is approximate because
// LiFePO4 has a very flat discharge curve; use a BMS coulomb counter later.
static constexpr float BATTERY_EMPTY_V = 10.0f;
static constexpr float BATTERY_FULL_V = 14.6f;
static constexpr uint32_t DEBOUNCE_MS = 35;
static constexpr uint32_t LONG_PRESS_MS = 1200;
// Keep false until the real actuator, encoder, current-limit and E-stop
// adapters are wired and verified. The state machine below is the contract
// that the actuator adapter must drive; it must never be used to bypass safety.
static constexpr bool MOTION_ADAPTER_READY = true;
// Set true only after hardware E-stop, limit switches, current/temperature
// limits and a bench test are commissioned. The routine protocol remains
// usable in dry-run mode while this is false.
static constexpr bool MOTOR_OUTPUT_ENABLED = true;
// Commissioning dry-run: accepts Pi requests and reports timed
// flexion/extension cycles without driving any motor. Disable before hardware.
static constexpr bool COMMISSIONING_AUTO_COMPLETE = false;
static constexpr uint32_t DIRECTION_REST_MS = 700;
static constexpr uint32_t HOME_RETURN_MS = 7000;
static constexpr uint32_t WALK_KNEE_FLEX_MS = 2000;
static constexpr uint32_t WALK_THIGH_LIFT_MS = 4000;
static constexpr uint32_t WALK_RETURN_MS = 5000;

struct Exercise { const char* code; const char* title; const char* side; };
static constexpr Exercise EXERCISES[] = {
  {"walk", "WALK", "BOTH"},
  {"raise_left_leg", "RAISE L", "LEFT"},
  {"raise_right_leg", "RAISE R", "RIGHT"},
  {"sit_to_stand", "SIT-STAND", "BOTH"},
  {"kick_left_leg", "KICK L", "LEFT"},
  {"kick_right_leg", "KICK R", "RIGHT"},
  {"kick_left_knee", "KNEE L", "LEFT"},
  {"kick_right_knee", "KNEE R", "RIGHT"},
};
static constexpr size_t EXERCISE_COUNT = sizeof(EXERCISES) / sizeof(EXERCISES[0]);

#if EXO_HAS_OLED
Adafruit_SSD1306 display(128, 64, &Wire, -1);
#endif

uint8_t selectedExercise = 0;
bool exerciseRunning = false;
bool uartSeen = false;
// The cylinders' internal end-of-stroke switches are the current home/end
// protection. Keep the software state ready for the commissioned bench test.
bool estopActive = false;
String faultReason = "";
String activeSession;
uint16_t completedRepetitions = 0;
uint16_t targetSets = 1;
uint16_t targetRepetitions = 1;
uint16_t completedSets = 0;
uint32_t sessionStartedMs = 0;
uint32_t activeStartedMs = 0;
uint32_t activeAccumulatedMs = 0;
uint32_t lastRepetitionStartedMs = 0;
uint32_t lastProgressStatusMs = 0;
uint32_t lastRepetitionDurationMs = 0;
uint32_t totalRepetitions = 0;
bool exercisePaused = false;
enum MotionPhase {
  PHASE_IDLE,
  PHASE_HOME_DIRECTION_REST,
  PHASE_HOME,
  PHASE_HOME_REST,
  PHASE_RUN,
  PHASE_REST
};
MotionPhase motionPhase = PHASE_IDLE;
bool homeAfterStop = false;
String homeCompletionState;
uint32_t phaseStartedMs = 0;
uint8_t exerciseStepIndex = 0;
uint8_t exerciseStepCount = 0;
uint32_t lastUartRxMs = 0;
uint32_t lastDisplayMs = 0;
uint32_t lastBatteryMs = 0;
float batteryVoltage = -1.0f;
float batteryPercent = -1.0f;
bool imuReady = false;
const char* imuError = "not_initialized";
int imuWhoAmI = -1;
int imuAccelConfig = -1;
int imuGyroConfig = -1;
uint32_t lastImuSampleMs = 0;
uint32_t lastImuConfigCheckMs = 0;
uint32_t imuSequence = 0;

enum MotorDirection : int8_t { MOTOR_STOP = 0, MOTOR_OUT = 1, MOTOR_IN = -1 };
MotorDirection lastMotorDirection[] = {MOTOR_IN, MOTOR_IN, MOTOR_IN, MOTOR_IN};
uint32_t motorStoppedAt[] = {0, 0, 0, 0};

struct ExerciseStep {
  MotorDirection c1;
  MotorDirection c2;
  MotorDirection c3;
  MotorDirection c4;
  uint32_t c1DurationMs;
  uint32_t c2DurationMs;
  uint32_t c3DurationMs;
  uint32_t c4DurationMs;
};

ExerciseStep exercisePlan[8];

struct MotorPins { int in1; int in2; };
static constexpr MotorPins C1_PINS{19, 18};
static constexpr MotorPins C2_PINS{5, 27};
static constexpr MotorPins C3_PINS{26, 25};
static constexpr MotorPins C4_PINS{33, 32};
String activeMotor;
uint32_t activeMotorUntilMs = 0;

struct ButtonState {
  uint8_t pin; bool stableLevel; bool lastReading;
  uint32_t changedAt; uint32_t pressedAt; bool longPressSent;
};
ButtonState buttons[] = {
  {BUTTON_PREVIOUS, HIGH, HIGH, 0, 0, false},
  {BUTTON_NEXT, HIGH, HIGH, 0, 0, false},
  {BUTTON_SELECT, HIGH, HIGH, 0, 0, false},
};

uint16_t crc16(const uint8_t* data, size_t length) {
  uint16_t crc = 0xFFFF;
  while (length--) {
    crc ^= static_cast<uint16_t>(*data++) << 8;
    for (uint8_t bit = 0; bit < 8; ++bit)
      crc = (crc & 0x8000) ? static_cast<uint16_t>((crc << 1) ^ 0x1021)
                           : static_cast<uint16_t>(crc << 1);
  }
  return crc;
}

String jsonString(const String& line, const char* key, const char* fallback = "") {
  String needle = String("\"") + key + "\":\"";
  int start = line.indexOf(needle);
  if (start < 0) return String(fallback);
  start += needle.length();
  int end = line.indexOf('"', start);
  return end < 0 ? String(fallback) : line.substring(start, end);
}

int jsonInt(const String& line, const char* key, int fallback = 0) {
  String needle = String("\"") + key + "\":";
  int start = line.indexOf(needle);
  if (start < 0) return fallback;
  start += needle.length();
  int end = start;
  while (end < line.length() && (isDigit(line[end]) || line[end] == '-')) ++end;
  return line.substring(start, end).toInt();
}

int exerciseIndex(const String& code) {
  for (size_t i = 0; i < EXERCISE_COUNT; ++i)
    if (code == EXERCISES[i].code) return static_cast<int>(i);
  return -1;
}

void sendPayload(const String& payload) {
  char checksum[5];
  snprintf(checksum, sizeof(checksum), "%04X",
           crc16(reinterpret_cast<const uint8_t*>(payload.c_str()), payload.length()));
  ExoUart.print("EXO1|"); ExoUart.print(payload); ExoUart.print('|');
  ExoUart.print(checksum); ExoUart.print('\n');
}

void sendStatus(const String& state, const String& session = "", const String& reason = "") {
  const uint32_t now = millis();
  const uint32_t elapsedMs = sessionStartedMs == 0 ? 0 : now - sessionStartedMs;
  const uint32_t activeMs = activeAccumulatedMs +
      (exerciseRunning ? now - activeStartedMs : 0);
  const uint32_t targetTotal = static_cast<uint32_t>(targetSets) * targetRepetitions;
  String payload = String("{\"v\":1,\"type\":\"exercise_status\",\"session_id\":\"") +
    session + "\",\"exercise_code\":\"" + EXERCISES[selectedExercise].code +
    "\",\"state\":\"" + state + "\",\"reason\":\"" + reason +
    "\",\"completed_repetitions\":" + String(completedRepetitions) +
    ",\"completed_sets\":" + String(completedSets) +
    ",\"target_sets\":" + String(targetSets) +
    ",\"target_repetitions\":" + String(targetRepetitions) +
    ",\"elapsed_ms\":" + String(elapsedMs) +
    ",\"active_ms\":" + String(activeMs) +
    ",\"repetition_duration_ms\":" + String(lastRepetitionDurationMs) +
    ",\"total_repetitions\":" + String(totalRepetitions) +
    ",\"target_total_repetitions\":" + String(targetTotal) + "}";
  sendPayload(payload);
}

void sendDeviceStatus() {
  String payload = String("{\"v\":1,\"type\":\"device_status\",\"state\":\"") +
    (exerciseRunning ? "assisting" : "disarmed") +
    "\",\"battery_voltage\":" + String(batteryVoltage, 2) +
    ",\"battery_percent\":" + String(batteryPercent, 1) +
    ",\"estop_active\":" + (estopActive ? "true" : "false") +
    ",\"command_watchdog_ok\":false,\"imu_ready\":" + String(imuReady ? "true" : "false") +
    ",\"imu_channel\":" + String(MPU6050_CHANNEL) +
    ",\"imu_error\":\"" + imuError + "\"" +
    ",\"imu_who_am_i\":" + String(imuWhoAmI) +
    ",\"imu_accel_config\":" + String(imuAccelConfig) +
    ",\"imu_gyro_config\":" + String(imuGyroConfig) +
    ",\"button_previous\":" + String(digitalRead(BUTTON_PREVIOUS)) +
    ",\"button_next\":" + String(digitalRead(BUTTON_NEXT)) +
    ",\"button_select\":" + String(digitalRead(BUTTON_SELECT)) +
    ",\"fault_reason\":\"" + faultReason + "\"}";
  sendPayload(payload);
}

bool selectI2cChannel(uint8_t channel) {
  if (channel > 7) return false;
  Wire.beginTransmission(TCA9548A_ADDRESS);
  Wire.write(static_cast<uint8_t>(1U << channel));
  return Wire.endTransmission() == 0;
}

bool mpuWriteRegister(uint8_t reg, uint8_t value) {
  if (!selectI2cChannel(MPU6050_CHANNEL)) return false;
  Wire.beginTransmission(MPU6050_ADDRESS);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}

bool mpuReadRegister(uint8_t reg, uint8_t& value) {
  if (!selectI2cChannel(MPU6050_CHANNEL)) return false;
  Wire.beginTransmission(MPU6050_ADDRESS);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0 ||
      Wire.requestFrom(MPU6050_ADDRESS, static_cast<uint8_t>(1)) != 1)
    return false;
  value = Wire.read();
  return true;
}

bool mpuRangesConfigured() {
  uint8_t accelConfig = 0;
  uint8_t gyroConfig = 0;
  imuAccelConfig = -1;
  imuGyroConfig = -1;
  if (!mpuReadRegister(0x1C, accelConfig)) {
    imuError = "accel_config_read_failed";
    return false;
  }
  imuAccelConfig = accelConfig;
  if (!mpuReadRegister(0x1B, gyroConfig)) {
    imuError = "gyro_config_read_failed";
    return false;
  }
  imuGyroConfig = gyroConfig;
  if ((accelConfig & 0x18) != 0x18 || (gyroConfig & 0x18) != 0x18) {
    imuError = "range_mismatch";
    return false;
  }
  imuError = "";
  return true;
}

bool initMpu6050() {
  uint8_t whoAmI = 0;
  imuWhoAmI = -1;
  if (!mpuReadRegister(0x75, whoAmI)) {
    imuError = "who_am_i_read_failed";
    return false;
  }
  imuWhoAmI = whoAmI;
  // Some boards sold as MPU6050 contain an MPU6500 (WHO_AM_I = 0x70).
  // Both use this register layout and the configured ±16g/±2000°/s scales.
  if (whoAmI != 0x68 && whoAmI != 0x69 && whoAmI != 0x70) {
    imuError = "who_am_i_mismatch";
    return false;
  }

  // Match the SisFall training ranges: accelerometer ±16g and gyro ±2000°/s.
  if (!mpuWriteRegister(0x6B, 0x00)) {
    imuError = "wake_write_failed";
    return false;
  }
  delay(10); // Let the sensor wake before configuring and checking its ranges.
  if (!mpuWriteRegister(0x1C, 0x18)) {
    imuError = "accel_config_write_failed";
    return false;
  }
  if (!mpuWriteRegister(0x1B, 0x18)) {
    imuError = "gyro_config_write_failed";
    return false;
  }
  if (!mpuWriteRegister(0x1A, 0x03)) {
    imuError = "filter_config_write_failed";
    return false;
  }
  return mpuRangesConfigured();
}

int16_t readI2cInt16() {
  return static_cast<int16_t>((static_cast<int16_t>(Wire.read()) << 8) | Wire.read());
}

bool readMpu6050(float& ax, float& ay, float& az, float& gx, float& gy, float& gz) {
  if (!selectI2cChannel(MPU6050_CHANNEL)) return false;
  Wire.beginTransmission(MPU6050_ADDRESS);
  Wire.write(0x3B); // ACCEL_XOUT_H
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(MPU6050_ADDRESS, static_cast<uint8_t>(14)) != 14) return false;

  const int16_t rawAx = readI2cInt16();
  const int16_t rawAy = readI2cInt16();
  const int16_t rawAz = readI2cInt16();
  readI2cInt16(); // temperature, unused
  const int16_t rawGx = readI2cInt16();
  const int16_t rawGy = readI2cInt16();
  const int16_t rawGz = readI2cInt16();

  ax = static_cast<float>(rawAx) / 2048.0f;
  ay = static_cast<float>(rawAy) / 2048.0f;
  az = static_cast<float>(rawAz) / 2048.0f;
  gx = static_cast<float>(rawGx) / 16.4f;
  gy = static_cast<float>(rawGy) / 16.4f;
  gz = static_cast<float>(rawGz) / 16.4f;
  return true;
}

void sendImuSample() {
  const uint32_t now = millis();
  if (imuReady && !mpuRangesConfigured()) {
    imuReady = false;
    lastImuConfigCheckMs = now;
    return; // A reset MPU may have reverted to its default ±2g/±250°/s ranges.
  }
  if (!imuReady) {
    if (now - lastImuConfigCheckMs < IMU_CONFIG_CHECK_PERIOD_MS) return;
    lastImuConfigCheckMs = now;
    imuReady = initMpu6050();
    if (!imuReady) return;
  }
  float ax, ay, az, gx, gy, gz;
  if (!readMpu6050(ax, ay, az, gx, gy, gz)) {
    imuReady = false;
    imuError = "sample_read_failed";
    lastImuConfigCheckMs = now;
    return;
  }
  imuReady = true;
  String payload = String("{\"v\":1,\"type\":\"imu_sample\",\"sensor\":\"") +
    (imuWhoAmI == 0x70 ? "mpu6500" : "mpu6050") + "\",\"channel\":" +
    String(MPU6050_CHANNEL) + ",\"seq\":" + String(imuSequence++) +
    ",\"t_ms\":" + String(millis()) +
    ",\"ax\":" + String(ax, 6) + ",\"ay\":" + String(ay, 6) +
    ",\"az\":" + String(az, 6) + ",\"gx\":" + String(gx, 6) +
    ",\"gy\":" + String(gy, 6) + ",\"gz\":" + String(gz, 6) + "}";
  sendPayload(payload);
}

const MotorPins* motorPins(const String& motor) {
  if (motor == "C1") return &C1_PINS;
  if (motor == "C2") return &C2_PINS;
  if (motor == "C3") return &C3_PINS;
  if (motor == "C4") return &C4_PINS;
  return nullptr;
}

int motorIndex(const String& motor) {
  if (motor == "C1") return 0;
  if (motor == "C2") return 1;
  if (motor == "C3") return 2;
  if (motor == "C4") return 3;
  return -1;
}

void stopMotor(const String& motor) {
  const MotorPins* pins = motorPins(motor);
  if (!pins) return;
  digitalWrite(pins->in1, LOW); digitalWrite(pins->in2, LOW);
  const int index = motorIndex(motor);
  if (index >= 0) motorStoppedAt[index] = millis();
  if (activeMotor == motor) { activeMotor = ""; activeMotorUntilMs = 0; }
}

void stopAllMotors() {
  stopMotor("C1"); stopMotor("C2"); stopMotor("C3"); stopMotor("C4");
}

void setMotorDirection(const String& motor, MotorDirection direction) {
  const MotorPins* pins = motorPins(motor);
  if (!pins) return;
  if (direction == MOTOR_OUT) {
    digitalWrite(pins->in1, HIGH); digitalWrite(pins->in2, LOW);
  } else if (direction == MOTOR_IN) {
    digitalWrite(pins->in1, LOW); digitalWrite(pins->in2, HIGH);
  } else {
    digitalWrite(pins->in1, LOW); digitalWrite(pins->in2, LOW);
  }
}

void addExerciseStep(MotorDirection c1, MotorDirection c2,
                     MotorDirection c3, MotorDirection c4,
                     uint32_t durationMs) {
  if (exerciseStepCount >= sizeof(exercisePlan) / sizeof(exercisePlan[0])) return;
  exercisePlan[exerciseStepCount++] = {c1, c2, c3, c4,
                                       durationMs, durationMs,
                                       durationMs, durationMs};
}

void addExerciseStepWithMotorTimes(MotorDirection c1, uint32_t c1DurationMs,
                                   MotorDirection c2, uint32_t c2DurationMs,
                                   MotorDirection c3, uint32_t c3DurationMs,
                                   MotorDirection c4, uint32_t c4DurationMs) {
  if (exerciseStepCount >= sizeof(exercisePlan) / sizeof(exercisePlan[0])) return;
  exercisePlan[exerciseStepCount++] = {c1, c2, c3, c4,
                                       c1DurationMs, c2DurationMs,
                                       c3DurationMs, c4DurationMs};
}

uint32_t exerciseStepDurationMs(const ExerciseStep& step) {
  return max(max(step.c1DurationMs, step.c2DurationMs),
             max(step.c3DurationMs, step.c4DurationMs));
}

void buildExercisePlan() {
  exerciseStepCount = 0;
  const String code = EXERCISES[selectedExercise].code;

  if (code == "raise_right_leg") {
    addExerciseStep(MOTOR_STOP, MOTOR_OUT, MOTOR_STOP, MOTOR_STOP, 7000);
    addExerciseStep(MOTOR_STOP, MOTOR_IN, MOTOR_STOP, MOTOR_STOP, 5000);
  } else if (code == "raise_left_leg") {
    addExerciseStep(MOTOR_STOP, MOTOR_STOP, MOTOR_STOP, MOTOR_OUT, 7000);
    addExerciseStep(MOTOR_STOP, MOTOR_STOP, MOTOR_STOP, MOTOR_IN, 5000);
  } else if (code == "kick_right_knee") {
    addExerciseStep(MOTOR_OUT, MOTOR_STOP, MOTOR_STOP, MOTOR_STOP, 5000);
    addExerciseStep(MOTOR_IN, MOTOR_STOP, MOTOR_STOP, MOTOR_STOP, 7000);
  } else if (code == "kick_left_knee") {
    addExerciseStep(MOTOR_STOP, MOTOR_STOP, MOTOR_OUT, MOTOR_STOP, 5000);
    addExerciseStep(MOTOR_STOP, MOTOR_STOP, MOTOR_IN, MOTOR_STOP, 7000);
  } else if (code == "kick_right_leg") {
    addExerciseStep(MOTOR_OUT, MOTOR_OUT, MOTOR_STOP, MOTOR_STOP, 7000);
    addExerciseStep(MOTOR_IN, MOTOR_IN, MOTOR_STOP, MOTOR_STOP, 5000);
  } else if (code == "kick_left_leg") {
    addExerciseStep(MOTOR_STOP, MOTOR_STOP, MOTOR_OUT, MOTOR_OUT, 7000);
    addExerciseStep(MOTOR_STOP, MOTOR_STOP, MOTOR_IN, MOTOR_IN, 5000);
  } else if (code == "walk") {
    // Start thigh lift and knee flexion together. Stop the knee after 2s;
    // keep the thigh lifting for 2s more, then return both joints HOME.
    addExerciseStepWithMotorTimes(
        MOTOR_OUT, WALK_KNEE_FLEX_MS, MOTOR_OUT, WALK_THIGH_LIFT_MS,
        MOTOR_STOP, 0, MOTOR_STOP, 0);
    addExerciseStep(MOTOR_IN, MOTOR_IN, MOTOR_STOP, MOTOR_STOP, WALK_RETURN_MS);
    addExerciseStepWithMotorTimes(
        MOTOR_STOP, 0, MOTOR_STOP, 0,
        MOTOR_OUT, WALK_KNEE_FLEX_MS, MOTOR_OUT, WALK_THIGH_LIFT_MS);
    addExerciseStep(MOTOR_STOP, MOTOR_STOP, MOTOR_IN, MOTOR_IN, WALK_RETURN_MS);
  } else if (code == "sit_to_stand") {
    addExerciseStep(MOTOR_STOP, MOTOR_OUT, MOTOR_STOP, MOTOR_OUT, 7000);
    addExerciseStep(MOTOR_STOP, MOTOR_IN, MOTOR_STOP, MOTOR_IN, 5000);
  }
}

void applyExerciseStep() {
  if (exerciseStepIndex >= exerciseStepCount) return;
  const ExerciseStep& step = exercisePlan[exerciseStepIndex];
  stopAllMotors();
  setMotorDirection("C1", step.c1);
  setMotorDirection("C2", step.c2);
  setMotorDirection("C3", step.c3);
  setMotorDirection("C4", step.c4);
  phaseStartedMs = millis();
  lastMotorDirection[0] = step.c1;
  lastMotorDirection[1] = step.c2;
  lastMotorDirection[2] = step.c3;
  lastMotorDirection[3] = step.c4;
  motionPhase = PHASE_RUN;
  const bool extending = step.c1 == MOTOR_IN || step.c2 == MOTOR_IN ||
                         step.c3 == MOTOR_IN || step.c4 == MOTOR_IN;
  sendStatus(extending ? "extending" : "flexing", activeSession);
}

void finishExerciseRepetition() {
  const uint32_t now = millis();
  lastRepetitionDurationMs = now - lastRepetitionStartedMs;
  lastRepetitionStartedMs = now;
  ++completedRepetitions;
  ++totalRepetitions;
  if (completedRepetitions >= targetRepetitions) {
    completedRepetitions = 0;
    ++completedSets;
  }
  if (completedSets >= targetSets) {
    activeAccumulatedMs += now - activeStartedMs;
    exerciseRunning = false;
    homeAfterStop = true;
    homeCompletionState = "completed";
    motionPhase = PHASE_HOME_DIRECTION_REST;
    phaseStartedMs = millis();
    stopAllMotors();
    sendStatus("extending", activeSession, "final HOME position");
    return;
  }
  exerciseStepIndex = 0;
  applyExerciseStep();
}

void beginHomeReturn(bool afterStop) {
  homeAfterStop = afterStop;
  homeCompletionState = afterStop ? "stopped" : "";
  exerciseRunning = false;
  exercisePaused = false;
  // Never reverse directly. Stop for 700 ms before driving every cylinder IN.
  motionPhase = PHASE_HOME_DIRECTION_REST;
  phaseStartedMs = millis();
  stopAllMotors();
  sendStatus(afterStop ? "stopping" : "extending", activeSession,
             afterStop ? "returning all cylinders to HOME" : "initial HOME position");
}

void handleMotorCommand(const String& payload) {
  const String motor = jsonString(payload, "motor");
  const String direction = jsonString(payload, "direction");
  const String session = jsonString(payload, "session_id");
  const MotorPins* pins = motorPins(motor);
  const int index = motorIndex(motor);
  const int durationMs = constrain(jsonInt(payload, "duration_ms", 0), 0, 30000);
  if (!pins || (direction != "OUT" && direction != "IN" && direction != "STOP")) {
    sendStatus("rejected", session, "invalid motor command"); return;
  }
  if (!MOTOR_OUTPUT_ENABLED || estopActive) {
    stopAllMotors();
    sendStatus("not_ready", session, MOTOR_OUTPUT_ENABLED ? "E-stop active" : "motor adapter disabled");
    return;
  }
  if (direction == "STOP" || durationMs == 0) { stopMotor(motor); return; }
  if (exerciseRunning || exercisePaused || motionPhase != PHASE_IDLE) {
    sendStatus("rejected", session, "controller is busy with another exercise"); return;
  }
  if (activeMotor.length() > 0 && activeMotor != motor) {
    sendStatus("rejected", session, "another motor command is active"); return;
  }
  const MotorDirection requested = direction == "OUT" ? MOTOR_OUT : MOTOR_IN;
  if (activeMotor == motor &&
      static_cast<int32_t>(millis() - activeMotorUntilMs) < 0 &&
      requested != lastMotorDirection[index]) {
    sendStatus("rejected", session,
               "motor is still moving; STOP is required before reverse");
    return;
  }
  if (requested == lastMotorDirection[index]) {
    sendStatus("rejected", session, "joint is already in requested state"); return;
  }
  if (millis() - motorStoppedAt[index] < DIRECTION_REST_MS) {
    sendStatus("rejected", session, "direction change requires 700ms STOP"); return;
  }
  setMotorDirection(motor, requested);
  lastMotorDirection[index] = requested;
  activeMotor = motor; activeMotorUntilMs = millis() + static_cast<uint32_t>(durationMs);
}

void handleHomeCommand(const String& payload) {
  const String session = jsonString(payload, "session_id");
  const String action = jsonString(payload, "action");
  if (session.length() == 0 || (action != "prepare" && action != "stop" && action != "complete")) {
    sendStatus("rejected", session, "invalid home command");
    return;
  }
  activeSession = session;
  exerciseRunning = false;
  exercisePaused = false;
  homeAfterStop = true;
  homeCompletionState = action == "prepare" ? "home_ready" :
                        (action == "complete" ? "completed" : "stopped");
  motionPhase = PHASE_HOME_DIRECTION_REST;
  phaseStartedMs = millis();
  stopAllMotors();
  sendStatus(action == "stop" ? "stopping" : "extending", activeSession,
             "returning all cylinders to HOME");
}

void updateMotorCommand() {
  if (activeMotor.length() > 0 && static_cast<int32_t>(millis() - activeMotorUntilMs) >= 0) stopMotor(activeMotor);
}

void readBattery() {
  uint32_t totalMv = 0;
  constexpr int samples = 16;
  for (int i = 0; i < samples; ++i) totalMv += analogReadMilliVolts(BATTERY_ADC_PIN);
  float adcVoltage = (static_cast<float>(totalMv) / samples) / 1000.0f;
  batteryVoltage = adcVoltage * BATTERY_DIVIDER_RATIO;
  batteryPercent = constrain(
      (batteryVoltage - BATTERY_EMPTY_V) * 100.0f / (BATTERY_FULL_V - BATTERY_EMPTY_V),
      0.0f, 100.0f);
}

void sendSelection() {
  String payload = String("{\"v\":1,\"type\":\"exercise_selected\",\"exercise_code\":\"") +
    EXERCISES[selectedExercise].code + "\",\"index\":" + String(selectedExercise) + "}";
  sendPayload(payload);
  sendStatus("selected", "local-ui");
}

void sendButtonEvent(const char* button, const char* action) {
  String payload = String("{\"v\":1,\"type\":\"button_event\",\"button\":\"") +
    button + "\",\"action\":\"" + action + "\"}";
  sendPayload(payload);
}

void startExercise() {
  activeSession = "local-ui";
  targetSets = 1;
  targetRepetitions = 1;
  completedRepetitions = 0;
  completedSets = 0;
  totalRepetitions = 0;
  lastRepetitionDurationMs = 0;
  sessionStartedMs = millis();
  activeStartedMs = sessionStartedMs;
  activeAccumulatedMs = 0;
  lastRepetitionStartedMs = sessionStartedMs;
  exercisePaused = false;
  buildExercisePlan();
  exerciseStepIndex = 0;
  exerciseRunning = false;
  motionPhase = PHASE_IDLE;
  if (exerciseStepCount == 0) {
    sendStatus("rejected", activeSession, "exercise procedure is not configured");
    return;
  }
  if ((!MOTION_ADAPTER_READY && !COMMISSIONING_AUTO_COMPLETE) ||
      (estopActive && !COMMISSIONING_AUTO_COMPLETE)) {
    sendStatus("not_ready", activeSession, faultReason);
    return;
  }
  beginHomeReturn(false);
}

void stopExercise() {
  if (activeSession.length() == 0) activeSession = "local-ui";
  if (exerciseRunning) activeAccumulatedMs += millis() - activeStartedMs;
  beginHomeReturn(true);
}

void updateExercise() {
  if (motionPhase == PHASE_HOME_DIRECTION_REST) {
    if (millis() - phaseStartedMs >= DIRECTION_REST_MS) {
      setMotorDirection("C1", MOTOR_IN);
      setMotorDirection("C2", MOTOR_IN);
      setMotorDirection("C3", MOTOR_IN);
      setMotorDirection("C4", MOTOR_IN);
      for (uint8_t i = 0; i < 4; ++i) lastMotorDirection[i] = MOTOR_IN;
      motionPhase = PHASE_HOME;
      phaseStartedMs = millis();
    }
    return;
  }
  if (motionPhase == PHASE_HOME) {
    if (millis() - phaseStartedMs >= HOME_RETURN_MS) {
      stopAllMotors();
      motionPhase = PHASE_HOME_REST;
      phaseStartedMs = millis();
    }
    return;
  }
  if (motionPhase == PHASE_HOME_REST) {
    if (millis() - phaseStartedMs >= DIRECTION_REST_MS) {
      motionPhase = PHASE_IDLE;
      if (homeCompletionState.length() > 0) {
        String completedState = homeCompletionState;
        homeCompletionState = "";
        homeAfterStop = false;
        sendStatus(completedState, activeSession);
        sendDeviceStatus();
      } else {
        exerciseRunning = true;
        activeStartedMs = millis();
        exerciseStepIndex = 0;
        applyExerciseStep();
        sendStatus("running", activeSession);
      }
    }
    return;
  }
  if (!exerciseRunning || motionPhase == PHASE_IDLE) return;
  const uint32_t elapsed = millis() - phaseStartedMs;
  const ExerciseStep& step = exercisePlan[exerciseStepIndex];
  const uint32_t duration = exerciseStepDurationMs(step);
  if (motionPhase == PHASE_RUN) {
    if (step.c1 != MOTOR_STOP && step.c1DurationMs > 0 && elapsed >= step.c1DurationMs) stopMotor("C1");
    if (step.c2 != MOTOR_STOP && step.c2DurationMs > 0 && elapsed >= step.c2DurationMs) stopMotor("C2");
    if (step.c3 != MOTOR_STOP && step.c3DurationMs > 0 && elapsed >= step.c3DurationMs) stopMotor("C3");
    if (step.c4 != MOTOR_STOP && step.c4DurationMs > 0 && elapsed >= step.c4DurationMs) stopMotor("C4");
  }
  if (motionPhase == PHASE_RUN && elapsed >= duration) {
    stopAllMotors();
    motionPhase = PHASE_REST;
    phaseStartedMs = millis();
  } else if (motionPhase == PHASE_REST && elapsed >= DIRECTION_REST_MS) {
    ++exerciseStepIndex;
    if (exerciseStepIndex >= exerciseStepCount) finishExerciseRepetition();
    else applyExerciseStep();
  }
  if (exerciseRunning && millis() - lastProgressStatusMs >= 500) {
    lastProgressStatusMs = millis();
    const bool extending = exercisePlan[exerciseStepIndex].c1 == MOTOR_IN ||
                           exercisePlan[exerciseStepIndex].c2 == MOTOR_IN ||
                           exercisePlan[exerciseStepIndex].c3 == MOTOR_IN ||
                           exercisePlan[exerciseStepIndex].c4 == MOTOR_IN;
    sendStatus(motionPhase == PHASE_REST ? "extending" :
               (extending ? "extending" : "flexing"), activeSession);
  }
}

void renderDisplay() {
#if EXO_HAS_OLED
  if (millis() - lastDisplayMs < 200) return;
  lastDisplayMs = millis();
  display.clearDisplay(); display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1); display.setCursor(0, 0); display.print("EXOLEG  ");
  display.print(uartSeen && millis() - lastUartRxMs < 5000 ? "UART OK" : "UART ?");
  display.setCursor(0, 13); display.setTextSize(2); display.print(EXERCISES[selectedExercise].title);
  display.setTextSize(1); display.setCursor(0, 34); display.print("SIDE: ");
  display.print(EXERCISES[selectedExercise].side); display.setCursor(0, 45);
  display.print("BAT "); display.print(batteryVoltage, 2); display.print("V ");
  display.print(batteryPercent, 0); display.print("%"); display.setCursor(0, 56);
  display.print(estopActive ? "SAFE LOCK" : (exerciseRunning ? "RUNNING" : "READY")); display.display();
#endif
}

void handleButton(ButtonState& button) {
  bool reading = digitalRead(button.pin); uint32_t now = millis();
  if (reading != button.lastReading) button.changedAt = now;
  button.lastReading = reading;
  if (now - button.changedAt < DEBOUNCE_MS) return;
  if (reading != button.stableLevel) {
    button.stableLevel = reading;
    if (reading == LOW) {
      button.pressedAt = now;
      button.longPressSent = false;

      if (button.pin == BUTTON_PREVIOUS || button.pin == BUTTON_NEXT) {
        const char* name = button.pin == BUTTON_PREVIOUS ? "previous" : "next";
        sendButtonEvent(name, "pressed");
        if (exerciseRunning || exercisePaused || motionPhase != PHASE_IDLE ||
            activeMotor.length() > 0) {
          sendStatus("rejected", activeSession, "buttons locked while motion is active");
        } else {
          selectedExercise = button.pin == BUTTON_PREVIOUS
            ? (selectedExercise + EXERCISE_COUNT - 1) % EXERCISE_COUNT
            : (selectedExercise + 1) % EXERCISE_COUNT;
          sendSelection();
        }
      } else {
        sendButtonEvent("select", "pressed");
      }
    } else if (button.pin == BUTTON_SELECT && !button.longPressSent) {
      // A short SELECT press starts the selected routine. A long press is
      // consumed below and returns every cylinder to HOME.
      sendButtonEvent("select", "short_press");
      if (!exerciseRunning && !exercisePaused && motionPhase == PHASE_IDLE &&
          activeMotor.length() == 0) {
        startExercise();
      } else {
        sendStatus("rejected", activeSession, "exercise is already active");
      }
    }
  }
  if (button.pin == BUTTON_SELECT && button.stableLevel == LOW &&
      !button.longPressSent && now - button.pressedAt >= LONG_PRESS_MS) {
    button.longPressSent = true;
    sendButtonEvent("select", "long_press_stop");
    stopExercise();
  }
}

void handleFrame(const String& frame) {
  if (!frame.startsWith("EXO1|")) return;
  int separator = frame.lastIndexOf('|'); if (separator <= 5) return;
  String payload = frame.substring(5, separator), provided = frame.substring(separator + 1);
  provided.trim(); char expected[5];
  snprintf(expected, sizeof(expected), "%04X",
           crc16(reinterpret_cast<const uint8_t*>(payload.c_str()), payload.length()));
  if (!provided.equalsIgnoreCase(expected)) { sendStatus("rejected", "", "UART CRC failed"); return; }
  uartSeen = true; lastUartRxMs = millis(); String type = jsonString(payload, "type");
  if (type == "motor_command") {
    handleMotorCommand(payload);
  } else if (type == "home_command") {
    handleHomeCommand(payload);
  } else if (type == "exercise_command") {
    String session = jsonString(payload, "session_id"), code = jsonString(payload, "exercise_code");
    int index = exerciseIndex(code);
    if (index < 0) { sendStatus("rejected", session, "unsupported exercise code"); return; }
    selectedExercise = static_cast<uint8_t>(index); String action = jsonString(payload, "action");
    targetSets = constrain(jsonInt(payload, "sets", 1), 1, 20);
    targetRepetitions = constrain(jsonInt(payload, "repetitions", 1), 1, 100);
    if (action == "stop") {
      // Echo the request identity in the terminal HOME status so a mobile
      // client can wait for the physical return before changing screens.
      if (session.length() > 0) activeSession = session;
      stopExercise();
    }
    else if (action == "start") {
      const bool resume = exercisePaused && activeSession == session;
      if (!resume) {
        activeSession = session;
        completedRepetitions = 0;
        completedSets = 0;
        totalRepetitions = 0;
        lastRepetitionDurationMs = 0;
        sessionStartedMs = millis();
        activeAccumulatedMs = 0;
        lastRepetitionStartedMs = sessionStartedMs;
      }
      if ((!MOTION_ADAPTER_READY && !COMMISSIONING_AUTO_COMPLETE) ||
          (estopActive && !COMMISSIONING_AUTO_COMPLETE)) {
        sendStatus("not_ready", session, faultReason);
      } else {
        buildExercisePlan();
        exerciseStepIndex = 0;
        if (exerciseStepCount == 0) {
          sendStatus("rejected", session, "exercise procedure is not configured");
          return;
        }
        exerciseRunning = true;
        exercisePaused = false;
        activeStartedMs = millis();
        beginHomeReturn(false);
      }
    } else if (action == "pause") {
      if (exerciseRunning) activeAccumulatedMs += millis() - activeStartedMs;
      exerciseRunning = false;
      exercisePaused = true;
      motionPhase = PHASE_IDLE;
      stopAllMotors();
      sendStatus("paused", session);
    } else sendStatus("rejected", session, "unsupported exercise action");
  } else if (type == "device_command" || type == "ping") sendDeviceStatus();
  else sendStatus("rejected", "", "unsupported UART command");
}

void setup() {
  // CP210x USB bridge is connected to the ESP32 USB Type-C port.
  ExoUart.begin(BAUD);
  Wire.begin(21, 22);
  Wire.setClock(400000);
  // All three switches are externally pulled HIGH and connect the GPIO to
  // GND when pressed. GPIO34/35 do not have internal pull-up capability.
  pinMode(BUTTON_PREVIOUS, INPUT_PULLUP);
  pinMode(BUTTON_NEXT, INPUT);
  pinMode(BUTTON_SELECT, INPUT);
  pinMode(C1_PINS.in1, OUTPUT); pinMode(C1_PINS.in2, OUTPUT);
  pinMode(C2_PINS.in1, OUTPUT); pinMode(C2_PINS.in2, OUTPUT);
  pinMode(C3_PINS.in1, OUTPUT); pinMode(C3_PINS.in2, OUTPUT);
  pinMode(C4_PINS.in1, OUTPUT); pinMode(C4_PINS.in2, OUTPUT);
  stopAllMotors();
  analogReadResolution(12);
  analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);
#if EXO_HAS_OLED
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay(); display.display();
#endif
  delay(250);
  imuReady = initMpu6050();
  lastImuConfigCheckMs = millis();
  readBattery(); sendDeviceStatus(); sendSelection();
}

void loop() {
  static String line;
  while (ExoUart.available()) {
    char character = static_cast<char>(ExoUart.read());
    if (character == '\n') { handleFrame(line); line = ""; }
    else if (line.length() < 900) line += character; else line = "";
  }
  for (ButtonState& button : buttons) handleButton(button);
  updateExercise();
  updateMotorCommand();
  if (millis() - lastImuSampleMs >= IMU_SAMPLE_PERIOD_MS) {
    lastImuSampleMs += IMU_SAMPLE_PERIOD_MS;
    sendImuSample();
  }
  if (millis() - lastBatteryMs >= 1000) {
    lastBatteryMs = millis();
    readBattery();
    sendDeviceStatus();
  }
  renderDisplay();
}
