# BLE exercise preparation protocol v1

The Pi advertises as `ExoLeg-1`. The short name is intentional because the
128-bit service UUID and a long local name can exceed the legacy BLE
advertisement payload limit.

Pi exposes one service:

| Characteristic | UUID suffix | Direction | Purpose |
| --- | --- | --- | --- |
| Exoskeleton service | `6e400101-b5a3-f393-e0a9-e50e24dcca9e` | — | GATT service, schema v2 |
| Control | `...0002-b5a3-f393-e0a9-e50e24dcca9e` | app → Pi, write with response | Request preparation |
| Status | `...0003-b5a3-f393-e0a9-e50e24dcca9e` | Pi → app, notification | Exercise readiness/status |

All values are UTF-8 JSON, at most 384 bytes. A client must wait for the write
response and then the status notification; a successful BLE write is only receipt,
not approval to operate the device.

Preparation request:

```json
{"v":1,"type":"prepare_exercise","session_id":"server-session-id","plan_item_id":"plan-id","exercise_code":"sit_to_stand","sets":3,"repetitions":10}
```

Status notification:

```json
{"v":1,"type":"exercise_status","session_id":"server-session-id","state":"prepared","reason":"","completed_repetitions":0,"completed_sets":0,"target_sets":3,"target_repetitions":10,"elapsed_ms":0,"active_ms":0,"repetition_duration_ms":0,"total_repetitions":0,"target_total_repetitions":30}
```

Allowed status states are `prepared`, `not_ready`, `rejected`, `running`,
`flexing`, `extending`, `paused`, `stopped`, and `completed`. The ESP32 emits
`completed` only after the final extension of the final set.
`prepared` only says Pi has accepted the exercise metadata; it does not arm motors.
Later hardware/session nodes may publish progress status on `/exo/exercise/status`,
which the bridge forwards without changing its GATT contract.

Progress telemetry is produced by the ESP32 and forwarded unchanged. `completed_repetitions`
is the count in the current set; `completed_sets` is the number of finished sets;
`total_repetitions` is the cumulative count for the session. `elapsed_ms` includes pauses,
while `active_ms` excludes paused time. `repetition_duration_ms` is the latest completed
repetition duration. Until the encoder/actuator adapter is commissioned, the ESP32 uses its
commissioning phase timer as a safe simulation source for these values.

Exercise command:

```json
{"v":1,"type":"exercise_command","session_id":"server-session-id","plan_item_id":"plan-id","exercise_code":"raise_left_leg","action":"start","side":"left","sets":2,"repetitions":8,"assist_percent":20}
```

Supported exercise codes are `walk`, `raise_left_leg`, `raise_right_leg`,
`sit_to_stand`, `kick_left_leg`, `kick_right_leg`, `kick_left_knee`, and
`kick_right_knee`. Actions are `start`, `pause`, and `stop`; sides are `both`,
`left`, or `right`. SafetyGateway rejects commands unless the session was
prepared and the E-stop, watchdog, assist limit, and exercise code checks pass.
When the mobile client receives the final `completed` status, it posts
`/api/v1/patients/{patient_id}/training-sessions/complete`; the server
idempotently updates `training_sessions` and the plan item used by progress.
