# ESP32 USB serial controller

`exo_controller.ino` is the ESP32 local UI and commissioning controller. Use a
USB Type-C data cable from the ESP32 to the Pi. The CP210x bridge appears on
the Pi as `/dev/ttyUSB0`, at 921600 baud, 8N1. No Pi GPIO UART wiring is used.

## Local controls

The three buttons connect from the GPIO to GND and are active LOW:
GPIO13 = previous, GPIO34 = next, GPIO35 = short press start and hold 1.2
seconds stop/return HOME. GPIO13 uses its internal pull-up. GPIO34 and GPIO35
are input-only, so they require physical pull-up resistors. Selection and a
short start are locked while motion is active; long-stop remains available.
The 0.96-inch SSD1306
OLED uses I2C SDA=21, SCL=22 and address `0x3C`. Install `Adafruit GFX
Library` and `Adafruit SSD1306`; without them the UART controller still runs
without the display.

Battery sensing is on D14/GPIO14. Connect battery positive to D14 through
56 kOhm, connect D14 to GND through 10 kOhm, and share GND with the ESP32.
The firmware averages 16 ADC samples and reports battery_voltage and
battery_percent; the default percentage profile is 10.0--14.6 V for a 12V
LiFePO4 (4S) battery, configurable near the constants in the sketch. Voltage
alone is approximate for LiFePO4 because its discharge curve is flat; use BMS
coulomb-counting later for accurate state of charge. Never connect the battery
directly to GPIO14.

The firmware accepts frames from the Pi in this format:

```text
EXO1|{"type":"exercise_command",...}|CRC16\n
```

The menu and USB serial protocol use the same dataset, so a selected item can
later map directly to a motion profile. Commissioning mode currently performs
one dry-run flexion/extension cycle and reports `completed` without driving
motors. Disable it before connecting an actuator. Implement motor drivers only after adding encoder
validation, current/temperature limits, hardware E-stop, watchdog timeout, and
a bench/HIL test. Supported exercise codes are:

* `walk`
* `raise_left_leg`, `raise_right_leg`
* `sit_to_stand`
* `kick_left_leg`, `kick_right_leg`
* `kick_left_knee`, `kick_right_knee`
