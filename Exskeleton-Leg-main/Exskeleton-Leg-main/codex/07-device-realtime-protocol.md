# 07. Device và realtime protocol

## 1. Ranh giới

Protocol này phục vụ đồng bộ trạng thái, telemetry, event và **ý định** session/config. Nó không phải bus điều khiển motor thời gian thực. MCU/Pi luôn kiểm tra capability, hard limit, calibration, watchdog và safe-state trước khi thực thi.

## 2. Transport

- Pi ↔ backend: MQTT 5 qua TLS 1.2+; mỗi device có credential/certificate riêng.
- Mobile ↔ backend: HTTPS và WebSocket (`wss`).
- Mobile ↔ Pi: BLE chỉ provisioning, pairing assistance và trạng thái offline tối thiểu.
- Pi ↔ MCU: serial/CAN/UART với framing, checksum, sequence và watchdog; đặc tả electrical/frame riêng khi phần cứng chốt.

MQTT `client_id` gắn device ID, session không cho duplicate active connection trừ takeover có audit.

## 3. MQTT topics

```text
exo/v1/devices/{device_id}/telemetry       device -> cloud
exo/v1/devices/{device_id}/events          device -> cloud
exo/v1/devices/{device_id}/state/reported  device -> cloud
exo/v1/devices/{device_id}/acks            device -> cloud
exo/v1/devices/{device_id}/state/desired   cloud  -> device
exo/v1/devices/{device_id}/intents         cloud  -> device
```

ACL bắt buộc khóa đúng `{device_id}`. Device không subscribe/publish topic device khác. Không đưa patient name/email vào topic.

| Loại | QoS | Retain |
|---|---:|---:|
| Telemetry batch | 1 | No |
| Safety/event | 1 | No |
| Reported state | 1 | Yes (chỉ snapshot không nhạy cảm) |
| Desired state | 1 | Yes |
| Intent | 1 | No |
| Ack | 1 | No |

Critical event vẫn lưu local cho đến khi backend acknowledge ở application level; MQTT PUBACK một mình chưa chứng minh đã ghi DB.

## 4. Envelope chung

Payload dùng JSON trong pilot để debug; có thể chuyển Protobuf/CBOR khi benchmark chứng minh cần. Mọi message có schema version.

```json
{
  "message_id": "0190...",
  "schema_version": 1,
  "device_id": "0190...",
  "boot_id": "0190...",
  "sequence": 18420,
  "sent_at": "2026-07-17T14:30:01.240Z",
  "type": "telemetry_batch",
  "payload": {}
}
```

- `message_id`: UUIDv7/UUID duy nhất để idempotency.
- `boot_id`: đổi mỗi lần agent/MCU boot theo quy ước đã chốt.
- `sequence`: tăng đơn điệu trong boot scope; overflow/flash persistence phải định nghĩa ở firmware.
- Backend dùng receive time khi device clock không đáng tin và gắn quality flag `clock_drift`.

## 5. Telemetry batch

```json
{
  "message_id": "0190...",
  "schema_version": 1,
  "device_id": "0190...",
  "boot_id": "0190...",
  "sequence": 18420,
  "sent_at": "2026-07-17T14:30:01.240Z",
  "type": "telemetry_batch",
  "payload": {
    "session_id": "0190...",
    "sequence_start": 18400,
    "sequence_end": 18419,
    "sample_rate_hz": 50,
    "started_at": "2026-07-17T14:30:00.840Z",
    "calibration_version": 3,
    "samples": [
      {
        "dt_ms": 0,
        "trunk_pitch_deg": 4.1,
        "trunk_roll_deg": -1.2,
        "hip_left_deg": 18.4,
        "hip_right_deg": 17.9,
        "knee_left_deg": 32.6,
        "knee_right_deg": 31.8,
        "motor_current_left_ma": 820,
        "motor_current_right_ma": 790,
        "heart_rate_bpm": null,
        "flags": 0
      }
    ],
    "checksum": "sha256:..."
  }
}
```

Sampling thật (ví dụ 50 Hz) phải đo và chốt; live UI chỉ nhận aggregate 2–5 Hz. Batch giới hạn theo byte/time, ví dụ 0.5–2 giây, sau benchmark.

`flags` là bitmask versioned cho validity, limit/e-stop/motor state. Tài liệu bit-level được generate từ một schema dùng chung để Rust/Python/C/Flutter không lệch.

## 6. Safety event

```json
{
  "message_id": "0190...",
  "schema_version": 1,
  "device_id": "0190...",
  "boot_id": "0190...",
  "sequence": 18421,
  "sent_at": "2026-07-17T14:30:01.300Z",
  "type": "safety_event",
  "payload": {
    "event_id": "0190...",
    "session_id": "0190...",
    "event_type": "overcurrent",
    "severity": "critical",
    "occurred_at": "2026-07-17T14:30:01.260Z",
    "side": "left",
    "local_action": "motor_assistance_disabled",
    "requires_physical_reset": true,
    "snapshot": {
      "knee_deg": 41.2,
      "motor_current_ma": 5200,
      "limit_switch": false,
      "emergency_stop": false
    }
  }
}
```

Allowed `event_type` MVP: `emergency_stop`, `overcurrent`, `hard_limit`, `limit_switch`, `sensor_fault`, `watchdog_reset`, `unsafe_posture`, `movement_too_fast`, `device_disconnected`. Source và severity được validate; hardware critical không bị cloud hạ severity.

## 7. Reported và desired state

Reported snapshot:

```json
{
  "online": true,
  "mode": "idle",
  "active_session_id": null,
  "battery_percent": 78,
  "firmware_version": "1.2.0",
  "agent_version": "1.1.0",
  "protocol_version": 1,
  "config_version": 12,
  "calibration_version": 3,
  "sensors": { "imu": "ok", "hip_encoders": "ok", "knee_encoders": "ok" },
  "motors": { "left": "ok", "right": "ok" },
  "emergency_stop": false,
  "observed_at": "2026-07-17T14:30:00Z"
}
```

Desired state chỉ gồm config đã validate:

```json
{
  "config_version": 13,
  "valid_until": "2026-07-18T00:00:00Z",
  "assistance_level": "low",
  "approved_limit_profile_id": "0190...",
  "voice_locale": "vi",
  "signature": "..."
}
```

Device kiểm tra signature, monotonic version, expiration, capability và local hard limit. Nếu reject, ack có reason code; không retry vô hạn cùng config lỗi.

## 8. Session intents và acknowledgement

Intent types: `prepare_session`, `start_session`, `pause_session`, `resume_session`, `stop_session`, `cancel_preparation`. Không có `set_pwm`, `set_torque` hoặc raw motor command.

```json
{
  "intent_id": "0190...",
  "intent_type": "prepare_session",
  "session_id": "0190...",
  "expires_at": "2026-07-17T14:35:00Z",
  "config_snapshot_hash": "sha256:...",
  "payload": {
    "exercise_code": "sit_to_stand",
    "exercise_version": 2,
    "target": { "repetitions": 16 },
    "assistance_level": "low",
    "approved_limit_profile_id": "0190..."
  }
}
```

Ack:

```json
{
  "intent_id": "0190...",
  "session_id": "0190...",
  "status": "rejected",
  "reason_code": "preflight.calibration_required",
  "reported_session_state": "idle",
  "processed_at": "2026-07-17T14:30:02Z"
}
```

Ack status: `accepted`, `rejected`, `already_applied`, `expired`. Backend state transition dựa trên ack/event, không dựa trên việc publish thành công.

## 9. Offline và retry

- Pi dùng durable queue; ghi local trước khi publish.
- Retry exponential backoff + jitter, giữ nguyên message ID.
- Backend dedup; trả application ack có contiguous sequence cao nhất đã lưu.
- Khi gap, backend yêu cầu/resume upload theo range qua sync contract; không reorder bằng timestamp đơn thuần.
- Khi buffer gần đầy, ưu tiên safety event + session summary; raw telemetry áp dụng chính sách downsample/drop đã định nghĩa và gắn `data_loss` flag.
- Không cho session mới nếu storage/buffer ở trạng thái khiến safety evidence không thể lưu theo policy.

## 10. Mobile WebSocket

Endpoint: `GET /api/v1/realtime?token=<short_lived_ws_ticket>`; không đặt access token dài hạn trong URL log. Mobile lấy ticket bằng authenticated REST.

Client subscribe resource được authorize:

```json
{ "action": "subscribe", "channels": ["session:0190...", "device:0190..."] }
```

Server event:

```json
{
  "event_id": "0190...",
  "type": "session.live_updated",
  "occurred_at": "2026-07-17T14:30:02Z",
  "resource_version": 42,
  "data": {
    "session_id": "0190...",
    "elapsed_seconds": 121,
    "repetitions": 6,
    "posture": "correct",
    "trunk_pitch_deg": 4.1,
    "knee_left_deg": 32.6,
    "knee_right_deg": 31.8
  }
}
```

Event types: `device.state_changed`, `session.state_changed`, `session.live_updated`, `alert.created`, `assessment.updated`, `notification.created`.

WebSocket là hint/realtime view, không phải source of truth. Sau reconnect, app gọi REST lấy snapshot mới dựa trên resource version.

## 11. Compatibility và testing

- Backend công bố protocol min/max; firmware không tương thích bị chặn session nhưng vẫn được phép report health/upgrade state.
- Contract schema lưu trong repository (JSON Schema/Protobuf khi triển khai) và generate types nếu khả thi.
- Test: golden payload, unknown field, missing field, duplicate, out-of-order, corrupted checksum, clock drift, reconnect, broker unavailable và firmware downgrade.
- Fault injection bắt buộc chứng minh e-stop/overcurrent hoạt động khi Pi/backend/network đều lỗi.

