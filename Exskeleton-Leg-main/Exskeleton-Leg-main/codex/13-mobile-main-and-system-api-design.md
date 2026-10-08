# 13. Thiết kế phase tiếp theo: mobile main shell và API hệ thống

## 1. Trạng thái hiện tại

Auth đã có cả ở backend và mobile.

Backend hiện có:

- REST namespace `/api/v1`.
- `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /me`.
- `users`, `user_roles`, `refresh_sessions` trong migration.
- JWT access token, Argon2id password hash, opaque refresh token, refresh token rotation, revoke session khi logout.
- Role mặc định khi đăng ký là `patient`.

Mobile hiện có:

- Login/register page.
- `AuthBloc`, route guard, splash kiểm tra trạng thái đăng nhập.
- Token lưu trong secure storage qua `OauthTokenManager`.
- Dio tự gắn `Authorization`, refresh token khi gặp `401`, clear session khi không refresh được.

Phần chưa có:

- Main app shell với `NavigationBar`.
- Các page chính sau đăng nhập: Hôm nay, Bài tập, Tiến độ, Thiết bị, Cá nhân.
- API triển khai thật cho patient/device/exercise/plan/session/progress/notification.
- Realtime gateway cho session/device state.

## 2. Mục tiêu phase

Sau phase này, người dùng đăng nhập xong phải đi vào một app shell thật, không còn home placeholder. Mobile có thể gọi các API hệ thống bằng dữ liệu mock/server thật theo contract, và backend có skeleton module rõ ràng để phát triển từng lát dọc.

Luồng ưu tiên:

```text
Login/Register
  -> PatientShell
  -> Hôm nay
  -> Chọn bài
  -> Chuẩn bị
  -> Live session
  -> Kết quả
```

Caregiver/clinician có thể để sau MVP nếu chưa có dữ liệu quan hệ.

## 3. Patient mobile shell

Route chính:

```text
/patient
├─ /home
├─ /training
├─ /progress
├─ /device
└─ /profile
```

Flutter structure đề xuất:

```text
lib/features/patient_shell/
├─ presentation/
│  ├─ patient_shell_page.dart
│  └─ patient_destination.dart
lib/features/home/
lib/features/training/
lib/features/progress/
lib/features/devices/
lib/features/profile/
```

`PatientShellPage` dùng `AutoTabsRouter` hoặc nested AutoRoute. Bottom bar dùng Material 3 `NavigationBar`, label luôn hiển thị:

| Destination | Label | Icon | Route |
|---|---|---|---|
| `home` | Hôm nay | `home_outlined/home` | `/patient/home` |
| `training` | Bài tập | `fitness_center_outlined/fitness_center` | `/patient/training` |
| `progress` | Tiến độ | `monitoring_outlined/monitoring` | `/patient/progress` |
| `device` | Thiết bị | `settings_remote_outlined/settings_remote` | `/patient/device` |
| `profile` | Cá nhân | `person_outline/person` | `/patient/profile` |

Không hiển thị bottom navigation trên live session active. Live session nên là route fullscreen nằm ngoài shell:

```text
/patient/session/:id/live
/patient/session/:id/result
```

## 4. Thiết kế các page chính

### 4.1 Hôm nay

Route: `/patient/home`

Mục tiêu: người tập biết hôm nay cần làm gì và thiết bị có sẵn sàng không.

Khối UI:

- App bar: `Hôm nay`, notification icon, account menu.
- Greeting: `Xin chào, {display_name}`.
- Device status banner:
  - `ready`: Thiết bị sẵn sàng, pin, lần cuối đồng bộ.
  - `offline`: hướng dẫn bật thiết bị/kết nối.
  - `warning`: có vấn đề cần kiểm tra.
  - `critical`: ưu tiên cảnh báo, không che hành động gọi hỗ trợ.
- Next exercise card: tên bài, số set/reps hoặc thời lượng, mức hỗ trợ, nút `Bắt đầu`.
- Today progress: bài đã hoàn thành, phút tập, chất lượng trung bình.
- Alert preview: tối đa 3 cảnh báo chưa xem.

State:

- `loading`: skeleton giữ layout.
- `content`: đủ dữ liệu.
- `empty_plan`: chưa có bài hôm nay.
- `offline_stale`: hiển thị dữ liệu cũ kèm `Cập nhật lần cuối`.
- `recoverable_error`: retry.

API cần gọi:

- `GET /me`
- `GET /patients/{patient_id}/home`
- `GET /devices?patient_id={patient_id}`
- `GET /patients/{patient_id}/alerts?status=open&limit=3`

### 4.2 Bài tập

Route: `/patient/training`

Mục tiêu: chọn bài tập phù hợp.

Khối UI:

- Tabs/segmented: `Hôm nay`, `Tất cả`.
- Exercise list card: tên bài, mục tiêu, thời lượng, trạng thái plan, độ khó.
- Filter bottom sheet: loại bài, trạng thái, thiết bị cần thiết.
- Empty state: chưa có plan hoặc chưa ghép thiết bị.

Route con:

- `/patient/training/exercise/:exercise_id`
- `/patient/session/prepare?plan_item_id=...`

API cần gọi:

- `GET /patients/{patient_id}/plans/active`
- `GET /patients/{patient_id}/plan-items/today`
- `GET /exercises`
- `GET /exercises/{exercise_id}`

### 4.3 Chuẩn bị tập

Route: `/patient/session/prepare`

Mục tiêu: đảm bảo thiết bị, cảm biến, calibration và môi trường đạt điều kiện trước khi gửi start intent.

Checklist:

- Device online.
- Battery đủ.
- Sensor health ok.
- Motor/controller không báo fault.
- E-stop sẵn sàng.
- Calibration còn hiệu lực.
- Không có session active khác trên device.

Primary action:

- `Tôi đã sẵn sàng`, chỉ enable khi các check bắt buộc passed.

API cần gọi:

- `POST /sessions` với `Idempotency-Key`.
- `GET /sessions/{session_id}`
- `GET /devices/{device_id}`
- WebSocket/MQTT bridge event cho preflight nếu có.

### 4.4 Live session

Route: `/patient/session/:session_id/live`

Mục tiêu: hướng dẫn tập, hiển thị số liệu tối thiểu, phản ứng đúng với warning/critical.

Layout:

- Top app bar nhỏ: tên bài, pin/kết nối.
- Hero state: `Tư thế tốt`, `Chậm lại`, `Giữ lưng thẳng`, hoặc cảnh báo cụ thể.
- Metric chính: `6 / 16` reps hoặc timer.
- Tempo/cadence text.
- Joint summary đơn giản, không hiển thị raw chart mặc định.
- Controls: âm thanh/rung, `Tạm dừng`, `Kết thúc`.

Behavior:

- `start/pause/resume/stop` hiển thị `Đang chờ thiết bị xác nhận` cho tới khi backend/device xác nhận.
- `critical/aborted` là fullscreen alert, không cho quay lại active.
- End giữa chừng dùng hold-to-confirm hoặc dialog xác nhận rõ.

API/event:

- `POST /sessions/{session_id}/start`
- `POST /sessions/{session_id}/pause`
- `POST /sessions/{session_id}/resume`
- `POST /sessions/{session_id}/stop`
- `GET /sessions/{session_id}`
- `WS /realtime/user` hoặc `GET /sessions/{session_id}/events` fallback.

### 4.5 Kết quả và tiến độ

Routes:

- `/patient/session/:session_id/result`
- `/patient/progress`
- `/patient/progress/session/:session_id`

Kết quả buổi tập:

- Trạng thái: hoàn thành/đã dừng/hủy.
- Thời lượng.
- Reps target/completed/correct.
- Correctness ratio.
- ROM summary.
- Warning/critical count.
- 1-3 nhận xét dễ hiểu, tránh tạo áp lực.

Tiến độ:

- Segmented: `Tuần`, `Tháng`.
- Planned/completed.
- Tổng phút tập.
- Tỷ lệ đúng trung bình.
- Chart trend có unit/legend; missing data là gap.
- History list theo ngày.

API cần gọi:

- `GET /sessions/{session_id}/summary`
- `GET /patients/{patient_id}/progress/overview`
- `GET /patients/{patient_id}/progress/timeseries`
- `GET /patients/{patient_id}/sessions`

### 4.6 Thiết bị

Route: `/patient/device`

Mục tiêu: ghép, xem trạng thái, hiệu chỉnh và chẩn đoán ở mức an toàn.

Khối UI:

- Current device card: serial/model/firmware/pin/online.
- Readiness card: ready/blocking reasons.
- Calibration card: latest version, expiry, action `Hiệu chỉnh`.
- Diagnostics read-only: sensor, motor, controller, last seen.
- Pair/unpair action.

Route con:

- `/patient/device/pair`
- `/patient/device/calibrate`
- `/patient/device/diagnostics`

API cần gọi:

- `GET /devices`
- `GET /devices/{device_id}`
- `POST /devices/pair`
- `DELETE /devices/{device_id}/assignment`
- `GET /devices/{device_id}/calibrations/latest`
- `POST /devices/{device_id}/calibrations`

### 4.7 Cá nhân

Route: `/patient/profile`

Mục tiêu: quản lý hồ sơ, quyền chia sẻ, accessibility, privacy và logout.

Menu:

- Hồ sơ cá nhân.
- Mạng lưới chăm sóc.
- Thông báo.
- Trợ năng.
- Quyền riêng tư và dữ liệu.
- Trợ giúp.
- Phiên bản app/device.
- Đăng xuất.

API cần gọi:

- `GET /me`
- `GET /patients/{patient_id}`
- `PATCH /patients/{patient_id}`
- `GET /patients/{patient_id}/relationships`
- `POST /patients/{patient_id}/relationships/invitations`
- `GET/PATCH /notification-preferences`
- `GET /patients/{patient_id}/consents`
- `POST /patients/{patient_id}/consents`

## 5. API hệ thống cần thiết kế/triển khai

Auth đã có phần lõi. Các module tiếp theo nên tách theo bounded context:

```text
identity       # đã có
profiles       # patient profile, consent, relationships
devices        # pairing, health, calibration, configuration
exercises      # catalog/version
plans          # training plan, plan item
sessions       # prepare/start/pause/resume/stop/result
progress       # overview/timeseries/history
alerts         # safety alert feed, acknowledge/resolve
notifications  # inbox/preferences
realtime       # websocket event stream
operations     # health/ready/version
```

### 5.1 API bổ sung cho mobile home

Để giảm số request khi mở app, nên thêm endpoint tổng hợp:

```http
GET /api/v1/patients/{patient_id}/home
```

Response:

```json
{
  "data": {
    "patient": {
      "id": "0190...",
      "display_name": "Nguyễn An"
    },
    "device": {
      "id": "0190...",
      "online": true,
      "battery_percent": 78,
      "readiness": {
        "state": "ready",
        "blocking_reasons": []
      },
      "last_seen_at": "2026-07-18T08:00:00Z"
    },
    "next_plan_item": {
      "id": "0190...",
      "exercise": {
        "id": "0190...",
        "name": "Đứng lên và ngồi xuống"
      },
      "target": {
        "kind": "repetitions",
        "sets": 2,
        "repetitions_per_set": 8
      },
      "estimated_duration_seconds": 600
    },
    "today_progress": {
      "planned_count": 2,
      "completed_count": 1,
      "active_seconds": 420,
      "correctness_ratio": 0.82
    },
    "open_alerts": [
      {
        "id": "0190...",
        "severity": "warning",
        "title": "Calibration sắp hết hạn",
        "occurred_at": "2026-07-18T07:45:00Z"
      }
    ]
  },
  "meta": { "request_id": "0190..." }
}
```

Endpoint này chỉ gom dữ liệu đã được authorize; không thay thế endpoint chi tiết.

### 5.2 Endpoint matrix MVP

| Module | Method | Endpoint | Ưu tiên |
|---|---|---|---|
| identity | GET | `/me` | Đã có |
| profiles | GET/PATCH | `/patients/{patient_id}` | P0 |
| devices | GET | `/devices` | P0 |
| devices | GET | `/devices/{device_id}` | P0 |
| devices | POST | `/devices/pair` | P0 |
| devices | GET/POST | `/devices/{device_id}/calibrations/latest`, `/devices/{device_id}/calibrations` | P1 |
| exercises | GET | `/exercises`, `/exercises/{exercise_id}` | P0 |
| plans | GET | `/patients/{patient_id}/plans/active` | P0 |
| plans | GET | `/patients/{patient_id}/plan-items/today` | P0 |
| sessions | POST | `/sessions` | P0 |
| sessions | GET | `/sessions/{session_id}` | P0 |
| sessions | POST | `/sessions/{session_id}/start` | P0 |
| sessions | POST | `/sessions/{session_id}/pause` | P1 |
| sessions | POST | `/sessions/{session_id}/resume` | P1 |
| sessions | POST | `/sessions/{session_id}/stop` | P0 |
| sessions | GET | `/sessions/{session_id}/summary` | P0 |
| progress | GET | `/patients/{patient_id}/progress/overview` | P1 |
| progress | GET | `/patients/{patient_id}/sessions` | P1 |
| alerts | GET | `/patients/{patient_id}/alerts` | P0 |
| alerts | POST | `/alerts/{alert_id}/acknowledge` | P1 |
| notifications | GET | `/notifications` | P2 |
| notifications | GET/PATCH | `/notification-preferences` | P2 |

### 5.3 Realtime contract cho mobile

Mobile cần một stream theo user:

```http
GET /api/v1/realtime/user
Authorization: Bearer <access_token>
Upgrade: websocket
```

Message envelope:

```json
{
  "type": "session.updated",
  "resource_id": "0190...",
  "resource_version": 7,
  "occurred_at": "2026-07-18T08:00:00Z",
  "data": {
    "status": "active",
    "completed_repetitions": 6,
    "guidance": "good_posture"
  }
}
```

Event tối thiểu:

- `device.state_updated`
- `device.readiness_updated`
- `session.preflight_updated`
- `session.updated`
- `session.metric_updated`
- `session.alert_created`
- `notification.created`

Client xử lý:

- Nếu `resource_version` bị gap, refetch REST detail.
- Nếu mất kết nối, giữ state cũ và hiển thị `offline_stale`.
- Không dùng realtime event để bỏ qua authorization backend.

## 6. Thứ tự triển khai đề xuất

1. Mobile shell: tạo nested routes và `NavigationBar`, giữ `HomePage` hiện tại làm `PatientHomePage`.
2. Tạo UI state/model mock cho 5 tab để hoàn thiện trải nghiệm chính.
3. Backend thêm module `profiles`, `devices`, `exercises`, `plans`, `sessions` với repository skeleton và response contract.
4. Mobile thêm repository/usecase/BLoC cho home và training.
5. Nối `POST /sessions` và session live flow.
6. Sau khi device/Pi protocol ổn định, thêm realtime WebSocket và calibration.

Definition of done phase:

- Login/register xong vào `/patient/home`.
- Bottom navigation hoạt động đủ 5 tab.
- Mỗi tab có loading/content/empty/error/offline state.
- Mobile không hiển thị session active khi backend/device chưa xác nhận.
- Backend có OpenAPI hoặc API test cho các endpoint P0.
- Auth route cũ không bị phá vỡ.
