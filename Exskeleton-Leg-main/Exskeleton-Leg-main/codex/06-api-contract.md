# 06. REST API contract v1

## 1. Chuẩn chung

Base URL: `/api/v1`

Headers:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
X-Request-Id: <uuid-optional>
Idempotency-Key: <uuid-required-for-selected-mutations>
```

Success response:

```json
{
  "data": { "id": "0190..." },
  "meta": { "request_id": "0190..." }
}
```

List response:

```json
{
  "data": [{ "id": "0190..." }],
  "meta": {
    "request_id": "0190...",
    "next_cursor": "opaque-or-null"
  }
}
```

Error response dùng format trong `04-backend-rust.md`. Không bọc HTTP status 4xx/5xx thành `200`.

Query list chuẩn: `limit` mặc định 20, tối đa 100; `cursor` opaque; filter thời gian `from`, `to` là RFC 3339 UTC.

## 2. Authentication

| Method | Endpoint | Auth | Mục đích |
|---|---|---|---|
| POST | `/auth/register` | Public | Tạo patient account mặc định |
| POST | `/auth/login` | Public | Cấp access + refresh token |
| POST | `/auth/refresh` | Refresh token | Rotate token |
| POST | `/auth/logout` | User | Revoke refresh session hiện tại |
| POST | `/auth/password/forgot` | Public, rate-limited | Gửi reset flow, response không lộ email tồn tại |
| POST | `/auth/password/reset` | Reset token | Đặt password mới và revoke sessions cũ |
| GET | `/me` | User | Account, roles, profile summary |

Register:

```json
{
  "email": "user@example.com",
  "password": "strong-password",
  "display_name": "Nguyễn An",
  "locale": "vi",
  "timezone": "Asia/Ho_Chi_Minh",
  "accepted_terms_version": "2026-01"
}
```

Login response `data`:

```json
{
  "access_token": "...",
  "access_token_expires_in": 900,
  "refresh_token": "...",
  "refresh_token_expires_in": 2592000,
  "user": {
    "id": "0190...",
    "display_name": "Nguyễn An",
    "roles": ["patient"]
  }
}
```

Refresh token chỉ gửi trong body/secure channel và lưu bằng secure storage trên mobile; không ghi log.

## 3. Profile, consent và relationship

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| GET | `/patients/{patient_id}` | Self/related scoped | Hồ sơ patient |
| PATCH | `/patients/{patient_id}` | Self/clinician scoped | Cập nhật field cho phép |
| GET | `/patients/{patient_id}/consents` | Self | Lịch sử consent |
| POST | `/patients/{patient_id}/consents` | Self | Grant/withdraw consent version |
| GET | `/patients/{patient_id}/relationships` | Self | Danh sách người được chia sẻ |
| POST | `/patients/{patient_id}/relationships/invitations` | Self | Mời caregiver |
| POST | `/relationship-invitations/{token}/accept` | Invited user | Chấp nhận lời mời |
| DELETE | `/patients/{patient_id}/relationships/{id}` | Self/admin policy | Thu hồi quyền |
| GET | `/care/patients` | Caregiver/clinician | Patient được phép xem |

Patch profile dùng optimistic version:

```json
{
  "version": 3,
  "height_cm": 162,
  "mobility_level": "moderate",
  "emergency_contact": {
    "name": "Nguyễn Bình",
    "phone": "+84...",
    "relationship": "family"
  }
}
```

Không cho caregiver sửa hồ sơ/plan trừ khi scope và product policy cho phép rõ ràng.

## 4. Device và pairing

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| GET | `/devices` | User | Device actor được xem |
| GET | `/devices/{device_id}` | Owner/related | Metadata, capability, health |
| POST | `/devices/pair` | Patient + idempotency | Claim bằng code một lần |
| DELETE | `/devices/{device_id}/assignment` | Patient/admin | Unpair/revoke assignment |
| GET | `/devices/{device_id}/calibrations/latest` | Owner/clinician | Calibration gần nhất |
| POST | `/devices/{device_id}/calibrations` | Device/user flow | Khởi tạo calibration intent |
| POST | `/devices/{device_id}/configurations` | Clinician/self-policy | Đề nghị desired config hợp lệ |
| GET | `/devices/{device_id}/configurations/{version}` | Related | Trạng thái ack/reject |

Pair request:

```json
{
  "serial_number": "EXO-2026-000123",
  "pairing_code": "847291",
  "patient_id": "0190..."
}
```

Device detail không trả credential:

```json
{
  "data": {
    "id": "0190...",
    "serial_number": "EXO-2026-000123",
    "model": "exo-leg-v1",
    "firmware_version": "1.2.0",
    "protocol_version": 1,
    "online": true,
    "last_seen_at": "2026-07-17T14:30:00Z",
    "battery_percent": 78,
    "readiness": {
      "state": "ready",
      "blocking_reasons": []
    },
    "capabilities": {
      "hip_encoder_sides": ["left", "right"],
      "knee_motor_sides": ["left", "right"],
      "heart_rate": false
    }
  },
  "meta": { "request_id": "0190..." }
}
```

Config request chỉ dùng giá trị nghiệp vụ (`assistance_level`, approved limit profile); không nhận raw PWM/torque tùy ý.

## 5. Exercise catalog và plan

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| GET | `/exercises` | User | Catalog version đã publish phù hợp capability |
| GET | `/exercises/{exercise_id}` | User | Exercise và current version |
| GET | `/patients/{patient_id}/plans` | Related scoped | Danh sách plan |
| POST | `/patients/{patient_id}/plans` | Clinician/self-template policy | Tạo draft |
| GET | `/plans/{plan_id}` | Related scoped | Plan detail/items |
| PATCH | `/plans/{plan_id}` | Creator/clinician | Chỉnh draft với version |
| POST | `/plans/{plan_id}/publish` | Clinician/policy | Validate và publish revision |
| POST | `/plans/{plan_id}/pause` | Patient/clinician | Pause plan |

Plan item:

```json
{
  "exercise_version_id": "0190...",
  "order_index": 1,
  "schedule": {
    "days_of_week": [1, 3, 5],
    "preferred_time": "08:00"
  },
  "target": {
    "kind": "repetitions",
    "sets": 2,
    "repetitions_per_set": 8,
    "rest_seconds": 60
  },
  "safe_config": {
    "assistance_level": "low",
    "limit_profile_id": "clinically-approved-profile-id"
  }
}
```

Backend validate target theo `target_schema` và device compatibility; không tin JSON tùy ý.

## 6. Session

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| POST | `/sessions` | Patient + idempotency | Chuẩn bị session |
| GET | `/sessions/{session_id}` | Related scoped | State/detail |
| POST | `/sessions/{session_id}/start` | Patient | Gửi start intent sau ready |
| POST | `/sessions/{session_id}/pause` | Patient/device policy | Pause intent |
| POST | `/sessions/{session_id}/resume` | Patient/device policy | Resume intent; local re-check |
| POST | `/sessions/{session_id}/stop` | Patient | Stop intent |
| GET | `/sessions/{session_id}/summary` | Related scoped | Summary mới nhất/quality |
| GET | `/patients/{patient_id}/sessions` | Related scoped | History/filter |
| GET | `/sessions/{session_id}/assessments` | Related scoped | AI/rule results |
| GET | `/sessions/{session_id}/alerts` | Related scoped | Warning/critical events |

## 7. Mobile patient read models currently implemented

The current Flutter patient shell consumes these authenticated read models:

| Method | Endpoint | Response used by |
|---|---|---|
| GET | `/patients/{patient_id}/home` | Today home summary, next plan item, device readiness, alerts |
| GET | `/patients/{patient_id}/plan-items?scope=today\|all` | Training tabs |
| GET | `/patients/{patient_id}/progress/overview?period=week\|month` | Progress tabs and recent sessions |
| GET | `/devices?patient_id={patient_id}` | Device screen |
| GET | `/devices/{device_id}` | Device detail read model |
| GET | `/me/notifications` | Notification screen |
| POST | `/me/fcm-token` | Mobile push-token registration |

Exercise catalog response có các field `code`, `category`, `name_key`,
`description_key`, `instructions_key`, `safety_key`, `difficulty` và
`requires_support`. Mobile resolve các key này qua EN/VI i18n, nên API không
ghi cứng ngôn ngữ hiển thị.

These endpoints are backed by PostgreSQL through `PatientDataService`, with
Flyway migration `V202608310002__create_patient_data.sql`. Initial device,
exercise, and plan rows are created only when a patient has no patient data;
the API then returns the persisted rows. Training history remains empty until
a real session writer is connected, so the mobile UI displays “not enough
data” instead of hardcoded history.

The current backend does not yet expose hardware command endpoints for
calibration/diagnostics or session start/stop writes. The mobile app therefore
does not claim those operations succeeded; implementing them requires the
device protocol and session command contract described in sections 4 and 6.

Create session:

```json
{
  "patient_id": "0190...",
  "device_id": "0190...",
  "plan_item_id": "0190..."
}
```

Response `201`:

```json
{
  "data": {
    "id": "0190...",
    "status": "preparing",
    "exercise": {
      "code": "sit_to_stand",
      "name": "Đứng lên và ngồi xuống"
    },
    "target": { "kind": "repetitions", "total": 16 },
    "preflight": { "state": "pending", "checks": [] },
    "expires_at": "2026-07-17T14:35:00Z",
    "version": 1
  },
  "meta": { "request_id": "0190..." }
}
```

Start/pause/resume/stop trả trạng thái `intent_pending` hoặc resource state hiện tại; client theo dõi WebSocket/poll. Không giả vờ đã start trước khi device xác nhận.

Summary:

```json
{
  "data": {
    "session_id": "0190...",
    "status": "completed",
    "duration_seconds": 542,
    "repetitions": { "target": 16, "completed": 15, "correct": 12 },
    "correctness_ratio": 0.8,
    "range_of_motion": {
      "hip_left_deg": { "min": 4.2, "max": 72.8 },
      "knee_left_deg": { "min": 2.1, "max": 91.0 }
    },
    "alerts": { "info": 2, "warning": 1, "critical": 0 },
    "assessment_status": "completed",
    "quality_flags": []
  },
  "meta": { "request_id": "0190..." }
}
```

## 7. Progress, alerts và notifications

| Method | Endpoint | Quyền | Mục đích |
|---|---|---|---|
| GET | `/patients/{patient_id}/progress/overview` | Related scoped | Hôm nay/tuần và streak an toàn |
| GET | `/patients/{patient_id}/progress/timeseries` | Related scoped | Metric theo day/week/month |
| GET | `/patients/{patient_id}/alerts` | Related scoped | Alert feed |
| POST | `/alerts/{alert_id}/acknowledge` | Related scoped | Xác nhận đã xem |
| POST | `/alerts/{alert_id}/resolve` | Clinician/admin policy | Resolve với note |
| GET | `/notifications` | User | Inbox |
| POST | `/notifications/{id}/read` | Recipient | Mark read |
| GET/PATCH | `/notification-preferences` | User | Kênh và mức nhận |

Timeseries query ví dụ:

```http
GET /api/v1/patients/{id}/progress/timeseries?metric=correctness_ratio&granularity=week&from=2026-05-01T00:00:00Z&to=2026-07-18T00:00:00Z
```

Response point có `value: null` khi thiếu dữ liệu, không thay bằng 0.

## 8. Device-only HTTP endpoints

Ưu tiên MQTT cho realtime. HTTP dùng provisioning/bulk upload fallback:

| Method | Endpoint | Auth |
|---|---|---|
| POST | `/device/v1/provision/complete` | Bootstrap credential/mTLS |
| POST | `/device/v1/telemetry/batches` | Device credential + idempotency |
| POST | `/device/v1/events` | Device credential |
| GET | `/device/v1/configuration` | Device credential |

Namespace device tách khỏi user API để middleware/audience/rate limit riêng. Device credential chỉ thao tác `device_id` trong subject.

## 9. Health và operations

- `GET /health/live`: process sống, không query dependency.
- `GET /health/ready`: database/broker dependency đủ phục vụ.
- `GET /version`: build SHA, API/protocol range; có thể giới hạn public fields.
- Metrics endpoint chỉ mở trong private network/monitoring auth.

## 10. Compatibility

- Bổ sung optional field là backward-compatible; client phải bỏ qua field chưa biết.
- Không đổi nghĩa/type field trong v1; deprecate có thời hạn và telemetry usage.
- Enum client phải có `unknown`; server không gửi enum mới nếu old-client safety flow không xử lý được.
- OpenAPI được version control; CI kiểm tra breaking change.
