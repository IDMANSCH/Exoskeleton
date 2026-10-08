# 14. Mobile screen blueprints và API theo màn hình

Tài liệu này là bản thiết kế triển khai cho ứng dụng điện thoại. Mục tiêu là có UI rõ ràng, phù hợp người tập phục hồi chức năng, tuân thủ Material 3, không dùng gradient, không dùng hiệu ứng trang trí gây phân tâm.

## 1. Nguyên tắc thiết kế

- Nền dùng `colorScheme.surface`; section dùng `surfaceContainerLow` hoặc outline nhẹ.
- Không gradient, không orb/blob, không background trang trí.
- Mỗi màn hình chỉ có một hành động chính.
- Text tiếng Việt ngắn, trực tiếp, không đổ lỗi người tập.
- Mọi trạng thái nguy hiểm phải có icon + chữ + hành động cụ thể; không chỉ dựa vào màu.
- Bottom navigation chỉ xuất hiện khi người dùng đang duyệt app; ẩn trong live session.
- Không hiển thị raw motor control, raw PWM, raw torque hoặc field kỹ thuật nguy hiểm trên mobile.

## 2. App shell sau đăng nhập

Route gốc sau auth:

```text
/patient
```

Shell gồm `Scaffold` + `AutoTabsRouter` + `NavigationBar`.

Navigation destinations:

| Index | Route | Label | Icon | Selected icon |
|---:|---|---|---|---|
| 0 | `/patient/home` | Hôm nay | `Icons.home_outlined` | `Icons.home` |
| 1 | `/patient/training` | Bài tập | `Icons.fitness_center_outlined` | `Icons.fitness_center` |
| 2 | `/patient/progress` | Tiến độ | `Icons.monitoring_outlined` | `Icons.monitoring` |
| 3 | `/patient/device` | Thiết bị | `Icons.settings_remote_outlined` | `Icons.settings_remote` |
| 4 | `/patient/profile` | Cá nhân | `Icons.person_outline` | `Icons.person` |

Visual:

- `NavigationBar` height theo Material 3.
- Indicator dùng `primaryContainer`, không dùng gradient.
- Label luôn hiển thị để người cao tuổi dễ hiểu.
- Badge nhỏ cho `device` khi có warning/critical; badge nhỏ cho `profile` khi cần cập nhật consent.

Route ngoài shell:

```text
/patient/session/prepare
/patient/session/:session_id/live
/patient/session/:session_id/result
/patient/device/pair
/patient/device/calibrate
/patient/device/diagnostics
```

## 3. Màn hình PH-01: Hôm nay

Route: `/patient/home`

### Layout

```text
AppBar
  title: Hôm nay
  actions: notification, account menu

ListView
  Greeting section
  Device readiness banner
  Next exercise panel
  Today metrics row
  Open alerts list
  Recent session summary
```

### Component detail

Greeting:

- Title: `Xin chào, {display_name}`
- Supporting text theo thời điểm: `Hôm nay mình tập nhẹ và chắc nhé.`

Device readiness banner:

| State | Icon | Title | Action |
|---|---|---|---|
| `ready` | `check_circle` | `Thiết bị đã sẵn sàng` | `Xem thiết bị` |
| `offline` | `cloud_off` | `Thiết bị chưa kết nối` | `Kiểm tra` |
| `warning` | `warning_amber` | `Cần kiểm tra trước khi tập` | `Xem chi tiết` |
| `critical` | `error` | `Có sự cố an toàn chưa xử lý` | `Xem cảnh báo` |

Next exercise panel:

- Exercise name.
- Target summary: `2 hiệp x 8 lần`.
- Estimated duration: `Khoảng 10 phút`.
- Assistance level: `Hỗ trợ thấp`.
- Primary button: `Bắt đầu bài tập`.

Today metrics:

- `1 / 2` bài đã tập.
- `7 phút` thời gian tập.
- `82%` động tác đạt.

### States

| State | UI |
|---|---|
| `loading` | Skeleton cho banner, exercise, metrics |
| `content` | Hiển thị đủ dữ liệu |
| `empty_plan` | Card `Hôm nay chưa có bài tập` + action `Xem bài tập` |
| `no_device` | Card `Chưa ghép thiết bị` + action `Ghép thiết bị` |
| `offline_stale` | Giữ dữ liệu cũ, banner `Cập nhật lần cuối ...` |
| `recoverable_error` | Message ngắn + `Thử lại` |

### API

```http
GET /api/v1/patients/{patient_id}/home
```

Query optional:

| Field | Type | Note |
|---|---|---|
| `date` | `YYYY-MM-DD` | Mặc định theo timezone user |
| `include` | csv | `device,next_plan_item,metrics,alerts,recent_session` |

Response `data`:

```json
{
  "patient": {
    "id": "0190...",
    "display_name": "Nguyễn An",
    "timezone": "Asia/Ho_Chi_Minh"
  },
  "device": {
    "id": "0190...",
    "serial_number": "EXO-2026-000123",
    "online": true,
    "battery_percent": 78,
    "last_seen_at": "2026-07-18T08:00:00Z",
    "readiness": {
      "state": "ready",
      "blocking_reasons": []
    }
  },
  "next_plan_item": {
    "id": "0190...",
    "exercise_id": "0190...",
    "exercise_name": "Đứng lên và ngồi xuống",
    "target": {
      "kind": "repetitions",
      "sets": 2,
      "repetitions_per_set": 8
    },
    "assistance_level": "low",
    "estimated_duration_seconds": 600
  },
  "today_metrics": {
    "planned_count": 2,
    "completed_count": 1,
    "active_seconds": 420,
    "correctness_ratio": 0.82
  },
  "open_alerts": [],
  "recent_session": null
}
```

## 4. Màn hình TR-01: Bài tập

Route: `/patient/training`

### Layout

```text
AppBar: Bài tập
SegmentedButton: Hôm nay | Tất cả
Filter row
Exercise list
```

Exercise card:

- Leading icon/thumbnail đơn giản.
- Name.
- Target: reps/time.
- Chips: `Hôm nay`, `Đã hoàn thành`, `Cần thiết bị`.
- Trailing chevron.

Primary flow:

```text
Tap exercise
  -> exercise detail
  -> Chuẩn bị tập
```

### API

```http
GET /api/v1/patients/{patient_id}/plan-items/today
GET /api/v1/exercises?capability=exo-leg-v1&status=published
GET /api/v1/exercises/{exercise_id}
```

`GET /plan-items/today` response item:

```json
{
  "id": "0190...",
  "plan_id": "0190...",
  "exercise": {
    "id": "0190...",
    "code": "sit_to_stand",
    "name": "Đứng lên và ngồi xuống",
    "category": "strength"
  },
  "target": {
    "kind": "repetitions",
    "sets": 2,
    "repetitions_per_set": 8,
    "rest_seconds": 60
  },
  "safe_config": {
    "assistance_level": "low",
    "limit_profile_id": "0190..."
  },
  "status": "planned",
  "estimated_duration_seconds": 600
}
```

## 5. Màn hình TR-02: Chi tiết bài tập

Route: `/patient/training/exercise/:exercise_id`

### Layout

```text
AppBar
Exercise title
Illustration area on plain surface
Target and duration
Instruction stepper/list
Safety stop conditions
Primary action sticky bottom: Chuẩn bị tập
```

Không dùng video/ảnh tối màu hoặc gradient overlay. Nếu chưa có asset thật, dùng icon/illustration phẳng trên `surfaceContainerLow`.

### API

```http
GET /api/v1/exercises/{exercise_id}
```

Response `data`:

```json
{
  "id": "0190...",
  "code": "sit_to_stand",
  "name": "Đứng lên và ngồi xuống",
  "category": "strength",
  "current_version": {
    "id": "0190...",
    "version": 3,
    "instructions": [
      "Đặt hai chân vững trên sàn.",
      "Đứng lên chậm và giữ lưng thẳng.",
      "Ngồi xuống có kiểm soát."
    ],
    "required_capabilities": {
      "hip_encoder": true,
      "knee_motor": true
    },
    "stop_conditions": [
      "Đau hoặc chóng mặt",
      "Thiết bị báo dừng an toàn",
      "Mất thăng bằng"
    ]
  }
}
```

## 6. Màn hình TR-03: Chuẩn bị tập

Route: `/patient/session/prepare?plan_item_id={id}`

### Layout

```text
AppBar: Chuẩn bị
Exercise summary
Checklist card
Device status compact
Safety reminder
Sticky primary button
```

Checklist item:

- Icon status: pending/pass/warn/fail.
- Title dễ hiểu.
- Detail có mã kỹ thuật nếu cần hỗ trợ.

Required checks:

| Code | Text |
|---|---|
| `device_online` | Thiết bị đang kết nối |
| `battery_ok` | Pin đủ cho buổi tập |
| `sensors_ok` | Cảm biến hoạt động ổn định |
| `motors_ok` | Bộ hỗ trợ khớp gối sẵn sàng |
| `estop_ok` | Nút dừng khẩn cấp sẵn sàng |
| `calibration_valid` | Hiệu chỉnh còn hiệu lực |
| `no_active_session` | Không có buổi tập khác đang chạy |

### API

Create prepare intent:

```http
POST /api/v1/sessions
Idempotency-Key: <uuid>
```

Request:

```json
{
  "patient_id": "0190...",
  "device_id": "0190...",
  "plan_item_id": "0190..."
}
```

Response:

```json
{
  "id": "0190...",
  "status": "preparing",
  "exercise": {
    "id": "0190...",
    "name": "Đứng lên và ngồi xuống"
  },
  "target": {
    "kind": "repetitions",
    "total": 16
  },
  "preflight": {
    "state": "pending",
    "checks": [
      {
        "code": "device_online",
        "status": "passed",
        "message": "Thiết bị đang kết nối."
      }
    ]
  },
  "expires_at": "2026-07-18T08:10:00Z",
  "version": 1
}
```

Poll/fetch:

```http
GET /api/v1/sessions/{session_id}
```

## 7. Màn hình TR-05: Live session

Route: `/patient/session/:session_id/live`

### Layout

```text
Top bar: exercise name + connection/battery
Status hero
Main metric
Cadence guidance
Joint summary
Audio/haptic controls
Bottom actions
```

Bottom bar:

- `Tạm dừng`
- `Kết thúc`

Không có `NavigationBar` ở màn hình này.

### State UI

| Session state | UI |
|---|---|
| `intent_pending` | Spinner nhỏ + `Đang chờ thiết bị xác nhận` |
| `ready` | Button `Bắt đầu` |
| `active` | Metric lớn, guidance hiện tại |
| `warning` | Banner vàng với chỉ dẫn sửa |
| `paused` | Surface tĩnh + button `Tiếp tục` |
| `connection_lost` | Banner neutral, nói rõ thiết bị vẫn tự bảo vệ |
| `aborted` | Fullscreen critical, không resume |
| `completed` | Điều hướng kết quả |

### API

```http
POST /api/v1/sessions/{session_id}/start
POST /api/v1/sessions/{session_id}/pause
POST /api/v1/sessions/{session_id}/resume
POST /api/v1/sessions/{session_id}/stop
GET  /api/v1/sessions/{session_id}
```

Command response:

```json
{
  "id": "0190...",
  "status": "intent_pending",
  "pending_intent": {
    "kind": "start",
    "requested_at": "2026-07-18T08:00:00Z",
    "expires_at": "2026-07-18T08:00:10Z"
  },
  "version": 4
}
```

Realtime:

```http
GET /api/v1/realtime/user
Upgrade: websocket
```

Event:

```json
{
  "type": "session.metric_updated",
  "resource_id": "0190...",
  "resource_version": 8,
  "occurred_at": "2026-07-18T08:01:00Z",
  "data": {
    "status": "active",
    "completed_repetitions": 6,
    "target_repetitions": 16,
    "guidance": "good_posture",
    "tempo": "on_track",
    "connection": "online",
    "battery_percent": 76
  }
}
```

## 8. Màn hình RS-01: Kết quả buổi tập

Route: `/patient/session/:session_id/result`

### Layout

```text
AppBar: Kết quả
Result status
Summary metrics
ROM summary
Alerts summary
Notes/guidance
Primary action: Về hôm nay
Secondary action: Xem chi tiết
```

Copy cho aborted:

```text
Buổi tập đã dừng để bảo đảm an toàn.
```

### API

```http
GET /api/v1/sessions/{session_id}/summary
```

Response:

```json
{
  "session_id": "0190...",
  "status": "completed",
  "duration_seconds": 542,
  "repetitions": {
    "target": 16,
    "completed": 15,
    "correct": 12
  },
  "correctness_ratio": 0.8,
  "range_of_motion": {
    "hip_left_deg": { "min": 4.2, "max": 72.8 },
    "knee_left_deg": { "min": 2.1, "max": 91.0 }
  },
  "alerts": {
    "info": 2,
    "warning": 1,
    "critical": 0
  },
  "assessment_status": "completed",
  "quality_flags": []
}
```

## 9. Màn hình PR-01/PR-02: Tiến độ và lịch sử

Route: `/patient/progress`

### Layout

```text
AppBar: Tiến độ
SegmentedButton: Tuần | Tháng
Overview metric cards
Trend chart
History list
```

Chart rule:

- Có title, unit, legend.
- Không dùng màu đơn độc để phân biệt; thêm marker/line style.
- Missing data hiển thị gap.

### API

```http
GET /api/v1/patients/{patient_id}/progress/overview?period=week
GET /api/v1/patients/{patient_id}/progress/timeseries?metric=correctness_ratio&granularity=day&from=...&to=...
GET /api/v1/patients/{patient_id}/sessions?limit=20&cursor=...
```

Overview response:

```json
{
  "period": "week",
  "planned_count": 8,
  "completed_count": 6,
  "active_seconds": 3240,
  "correctness_ratio": 0.81,
  "warning_count": 3,
  "critical_count": 0,
  "streak_days": 4
}
```

Timeseries point:

```json
{
  "bucket_start": "2026-07-18T00:00:00Z",
  "bucket_end": "2026-07-19T00:00:00Z",
  "value": 0.82,
  "sample_count": 2,
  "quality_flags": []
}
```

## 10. Màn hình DV-01: Thiết bị

Route: `/patient/device`

### Layout

```text
AppBar: Thiết bị
Device identity card
Readiness card
Battery/connection row
Calibration card
Diagnostics entry
Pair/unpair action
```

Không có raw control. `Diagnostics` chỉ read-only.

### API

```http
GET /api/v1/devices?patient_id={patient_id}
GET /api/v1/devices/{device_id}
GET /api/v1/devices/{device_id}/calibrations/latest
```

Device detail response:

```json
{
  "id": "0190...",
  "serial_number": "EXO-2026-000123",
  "model": "exo-leg-v1",
  "firmware_version": "1.2.0",
  "protocol_version": 1,
  "online": true,
  "last_seen_at": "2026-07-18T08:00:00Z",
  "battery_percent": 78,
  "readiness": {
    "state": "ready",
    "blocking_reasons": []
  },
  "health": {
    "sensors": "ok",
    "motors": "ok",
    "controller": "ok",
    "estop": "ok"
  },
  "capabilities": {
    "hip_encoder_sides": ["left", "right"],
    "knee_motor_sides": ["left", "right"],
    "heart_rate": false
  }
}
```

## 11. Màn hình DV-02: Ghép thiết bị

Route: `/patient/device/pair`

### Layout

```text
AppBar: Ghép thiết bị
QR scan area or manual entry
Serial number input
Pairing code input
Patient confirmation
Primary action: Ghép thiết bị
```

### API

```http
POST /api/v1/devices/pair
Idempotency-Key: <uuid>
```

Request:

```json
{
  "serial_number": "EXO-2026-000123",
  "pairing_code": "847291",
  "patient_id": "0190..."
}
```

Response:

```json
{
  "device": {
    "id": "0190...",
    "serial_number": "EXO-2026-000123",
    "model": "exo-leg-v1"
  },
  "assignment": {
    "id": "0190...",
    "patient_id": "0190...",
    "status": "active",
    "assigned_at": "2026-07-18T08:00:00Z"
  }
}
```

## 12. Màn hình DV-03: Hiệu chỉnh

Route: `/patient/device/calibrate`

### Layout

```text
AppBar: Hiệu chỉnh
Stepper
  1. Đứng thẳng
  2. Giữ yên
  3. Xác nhận kết quả
Live sensor status
Primary action: Bắt đầu hiệu chỉnh / Lưu kết quả
```

### API

```http
POST /api/v1/devices/{device_id}/calibrations
GET  /api/v1/devices/{device_id}/calibrations/{calibration_id}
```

Request:

```json
{
  "patient_id": "0190...",
  "type": "standing_neutral"
}
```

Response:

```json
{
  "id": "0190...",
  "device_id": "0190...",
  "patient_id": "0190...",
  "type": "standing_neutral",
  "status": "pending",
  "version": 4,
  "expires_at": "2026-08-18T08:00:00Z"
}
```

## 13. Màn hình PF-01: Cá nhân

Route: `/patient/profile`

### Layout

```text
AppBar: Cá nhân
Account header
Menu list
Logout button
```

Menu:

- Hồ sơ cá nhân.
- Mạng lưới chăm sóc.
- Thông báo.
- Trợ năng.
- Quyền riêng tư và dữ liệu.
- Trợ giúp.
- Phiên bản ứng dụng.

### API

```http
GET /api/v1/me
GET /api/v1/patients/{patient_id}
PATCH /api/v1/patients/{patient_id}
GET /api/v1/patients/{patient_id}/relationships
GET /api/v1/patients/{patient_id}/consents
GET /api/v1/notification-preferences
PATCH /api/v1/notification-preferences
POST /api/v1/auth/logout
```

`PATCH /patients/{patient_id}` request:

```json
{
  "version": 3,
  "height_cm": 162,
  "weight_kg": 56,
  "mobility_level": "moderate",
  "emergency_contact": {
    "name": "Nguyễn Bình",
    "phone": "+84901234567",
    "relationship": "family"
  }
}
```

## 14. API conventions bổ sung

### Envelope

Mọi response dùng envelope:

```json
{
  "data": {},
  "meta": {
    "request_id": "0190..."
  }
}
```

List response có `next_cursor`.

### Error

```json
{
  "error": {
    "code": "device.not_ready",
    "message": "Thiết bị chưa sẵn sàng.",
    "details": {
      "blocking_reasons": ["calibration_expired"]
    }
  },
  "meta": {
    "request_id": "0190..."
  }
}
```

### Idempotency

Bắt buộc với:

- `POST /sessions`
- `POST /devices/pair`
- `POST /devices/{device_id}/calibrations`
- `POST /sessions/{session_id}/start`
- `POST /sessions/{session_id}/stop`

### Authorization

- Mobile guard chỉ phục vụ UX; backend vẫn kiểm tra quyền từng request.
- Patient chỉ xem/sửa dữ liệu của chính mình.
- Caregiver/clinician chỉ xem patient được cấp relationship scope.
- Device credential tách namespace `/device/v1`, không dùng user token.

## 15. Implementation slicing

### Slice 1: shell và page tĩnh

- Tạo `PatientShellPage`.
- Chuyển `HomePage` hiện tại thành `/patient/home`.
- Thêm 4 page placeholder có layout đúng: training, progress, device, profile.
- Dùng Material 3 theme, không gradient.

### Slice 2: home API

- Backend thêm `GET /patients/{patient_id}/home`.
- Mobile thêm `HomeRepository`, `HomeBloc`, state loading/content/empty/error/offline.

### Slice 3: training và session prepare

- Backend thêm exercises/plans/session prepare P0.
- Mobile thêm danh sách bài, chi tiết bài, chuẩn bị tập.

### Slice 4: live session

- Backend thêm session command endpoints.
- Mobile thêm live session fullscreen, command pending state, result screen.

### Slice 5: device và calibration

- Backend thêm devices/calibration.
- Mobile thêm pair/calibrate/diagnostics.

### Slice 6: progress và alerts

- Backend thêm progress, history, alerts.
- Mobile thêm chart/history/acknowledge.
