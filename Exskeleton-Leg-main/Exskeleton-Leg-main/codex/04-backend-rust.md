# 04. Backend Rust layered architecture

## 1. Mục tiêu

Backend dùng Rust + Axum theo **layered modular monolith**. Mỗi feature có bốn lớp; dependency chỉ đi vào trong:

```text
presentation/http ──> application ──> domain
infrastructure ─────> application/domain ports
bootstrap ──────────> tất cả để wiring
```

Domain không import Axum, SQLx, MQTT SDK, JWT library hoặc concrete database type.

## 2. Cấu trúc source đích

```text
Backend/
├─ Cargo.toml
├─ migrations/
├─ src/
│  ├─ main.rs                 # process entry only
│  ├─ lib.rs
│  ├─ bootstrap/
│  │  ├─ config.rs
│  │  ├─ state.rs
│  │  ├─ router.rs
│  │  └─ telemetry.rs
│  ├─ shared/
│  │  ├─ domain/              # Id, DomainError, Clock traits
│  │  ├─ application/         # transaction/outbox abstractions
│  │  ├─ infrastructure/      # db pool, auth crypto, messaging
│  │  └─ presentation/        # ApiError, envelope, middleware
│  ├─ modules/
│  │  ├─ identity/
│  │  │  ├─ domain/           # entity/value object/domain service
│  │  │  ├─ application/      # command/query, ports, DTO boundary
│  │  │  ├─ infrastructure/   # SQLx repo, JWT/Argon adapter
│  │  │  └─ presentation/     # Axum handlers/routes
│  │  ├─ devices/
│  │  ├─ exercises/
│  │  ├─ plans/
│  │  ├─ sessions/
│  │  ├─ telemetry/
│  │  ├─ safety/
│  │  ├─ assessments/
│  │  ├─ progress/
│  │  └─ notifications/
│  └─ workers/
│     ├─ outbox_dispatcher.rs
│     ├─ session_aggregator.rs
│     └─ notification_dispatcher.rs
└─ tests/
   ├─ api/
   ├─ repositories/
   └─ fixtures/
```

Không tạo thư mục global `models`, `services`, `repositories` khi mở rộng vì chúng làm mất ownership theo domain. Code hiện có được chuyển dần vào `modules/identity`.

## 3. Trách nhiệm từng lớp

### Domain

- Entity, aggregate, value object, invariant và domain event.
- Lỗi nghiệp vụ có mã ổn định, ví dụ `session.device_not_ready`.
- Pure Rust; unit test nhanh, không I/O.

### Application

- Use case/command/query handler và transaction boundary.
- Kiểm tra authorization theo policy/context.
- Gọi repository/clock/event publisher qua trait port.
- Trả application DTO, không trả SQL row.

### Infrastructure

- Implement port bằng SQLx/PostgreSQL, MQTT, FCM/APNs, object storage.
- Mapping database row ↔ domain; retry lỗi tạm thời có giới hạn.
- Không đặt business rule trong SQL repository.

### Presentation

- Route, extractor, parse/validate HTTP, status code, serialization.
- Map `AppError` sang error envelope.
- Không gọi repository trực tiếp; handler chỉ gọi use case.

## 4. Wiring và state

`AppState` chỉ chứa clone-cheap application services/gateways (`Arc<dyn Trait>` hoặc concrete facade), config công khai cần thiết và observability handle. Secret được nạp từ environment/secret manager, không hard-code.

Khuyến nghị dependency:

- HTTP/runtime: `axum`, `tokio`, `tower`, `tower-http`
- Serialization/validation: `serde`, `serde_json`, `validator`
- Database: `sqlx` với PostgreSQL, migration compile/runtime phù hợp CI
- Auth: `argon2`, `jsonwebtoken` hoặc PASETO nếu có quyết định riêng
- Time/ID: `time` hoặc `chrono`, `uuid`
- Observability: `tracing`, `tracing-subscriber`, OpenTelemetry exporter
- API schema: `utoipa` để sinh OpenAPI từ contract đã kiểm thử
- MQTT: client hỗ trợ TLS, QoS và reconnect (chốt qua ADR khi triển khai)

Không thêm crate chỉ vì phổ biến; dependency mới cần lý do, owner và kiểm tra license/security.

## 5. Command/query mẫu

```rust
pub struct StartSessionCommand {
    pub actor_id: UserId,
    pub session_id: SessionId,
}

#[async_trait]
pub trait SessionRepository: Send + Sync {
    async fn find_for_update(&self, id: SessionId) -> Result<Option<TrainingSession>, RepoError>;
    async fn save(&self, session: &TrainingSession) -> Result<(), RepoError>;
}

pub struct StartSessionHandler<R, D, U> {
    sessions: R,
    devices: D,
    unit_of_work: U,
}
```

Handler tải aggregate, authorize actor, kiểm tra state transition, ghi aggregate + outbox trong một transaction. Việc publish MQTT diễn ra qua outbox worker, không nằm trong database transaction.

## 6. HTTP conventions

- Prefix `/api/v1`; route danh từ số nhiều.
- JSON `snake_case`; timestamp RFC 3339 UTC.
- UUID string; decimal sensor values có đơn vị trong field name hoặc schema.
- Pagination cursor, không offset cho feed lớn.
- `Idempotency-Key` bắt buộc với create session, pairing claim và hành động có retry.
- `X-Request-Id` nhận từ client nếu hợp lệ hoặc server tạo; trả lại response.
- Optimistic concurrency cho resource chỉnh sửa: `version` + `If-Match`/field version.

## 7. Error model

```json
{
  "error": {
    "code": "session.device_not_ready",
    "message": "Thiết bị chưa sẵn sàng để bắt đầu buổi tập.",
    "details": { "reason": "calibration_required" },
    "request_id": "0190..."
  }
}
```

| Nhóm | HTTP | Ví dụ |
|---|---:|---|
| Validation | 422 | `validation.invalid_field` |
| Authentication | 401 | `auth.invalid_token` |
| Authorization | 403 | `authorization.denied` |
| Not found | 404 | `device.not_found` |
| State conflict | 409 | `session.invalid_state`, `device.already_claimed` |
| Rate limit | 429 | `rate_limit.exceeded` |
| Internal | 500 | `internal.unexpected` (không lộ chi tiết) |
| Temporarily unavailable | 503 | `dependency.unavailable` |

Message để hiển thị có thể localize ở app theo `code`; backend message là fallback. Không trả stack trace/SQL/secret.

## 8. Authentication và authorization

- Access token TTL ngắn (gợi ý 15 phút), refresh token opaque/rotating lưu hash.
- Device dùng certificate hoặc credential riêng, audience/scope riêng; không dùng user JWT.
- Authorization kiểm tra cả role và relationship/resource ownership trong application layer.
- Policy ví dụ: `ViewPatientProgress(actor, patient_id)`, `EditTrainingPlan(actor, patient_id)`, `IngestTelemetry(device, device_id)`.
- CORS allowlist theo environment; không dùng permissive ở staging/production.

## 9. Database và transaction

- Migration forward-only, tên timestamp + mô tả; CI chạy trên database sạch và upgrade snapshot.
- Constraint database bảo vệ invariant cơ bản (unique, foreign key, check status/range).
- Outbox record cùng transaction với aggregate.
- Các query list luôn có tenant/relationship filter; test chống IDOR.
- Không giữ transaction mở trong lúc gọi MQTT/push/AI.

## 10. Background jobs

Job envelope có `job_id`, `kind`, `payload_version`, `attempt`, `created_at`, `trace_id`. Consumer idempotent; retry exponential backoff + jitter; lỗi vĩnh viễn sang dead-letter và alert vận hành.

Job chính:

- Dispatch outbox.
- Aggregate live/session summary.
- Run/retry AI assessment.
- Send notification.
- Build daily/weekly progress.
- Enforce retention/anonymization.

## 11. Migration từ code hiện tại

1. Tạo `lib.rs`, `bootstrap` và shared error/config; giữ endpoint cũ hoạt động.
2. Chuyển auth vào `modules/identity` với repository trait.
3. Thêm PostgreSQL adapter và migration user/refresh token.
4. Đổi route thành `/api/v1/auth/*`, giữ alias cũ tạm thời nếu mobile cần.
5. Thêm module theo lát dọc: device pairing → exercise/plan → session → telemetry.
6. Xóa in-memory repository và secret hard-code khi integration test DB đã ổn định.

## 12. Definition of Done cho endpoint

- Có use case/invariant và authorization policy.
- Request validation, error code và OpenAPI schema.
- Unit test domain/application; integration test repository; API happy/error/permission test.
- Structured log/metric không chứa PII/secret.
- Idempotency/concurrency được xử lý nếu endpoint mutate.
- Migration/index/retention được xem xét nếu có dữ liệu mới.
- Tài liệu `06-api-contract.md` cập nhật.

