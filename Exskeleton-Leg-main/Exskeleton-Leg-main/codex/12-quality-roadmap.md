# 12. Chất lượng, vận hành và roadmap

## 1. Test pyramid theo thành phần

### Backend Rust

- Domain unit test: invariant/state transition/value object/property-based test khi phù hợp.
- Application test: fake port, authorization, idempotency, transaction/outbox behavior.
- Repository integration: PostgreSQL thật qua test container/database isolated.
- API contract: status/envelope/validation/authz/OpenAPI snapshot.
- Worker test: duplicate event, retry, poison message, dead-letter.
- Load test: telemetry ingest, session live fan-out, progress query.

### Flutter

- Unit: mapper, repository, formatter, BLoC transition.
- Widget: page state loading/content/empty/error/offline, text scale, semantics.
- Golden: theme/component/safety state ở phone tiêu chuẩn và large text.
- Integration: login, pair, pre-flight, session fake stream, reconnect, critical alert.
- Manual accessibility: TalkBack/VoiceOver, contrast, touch target, người cao tuổi pilot.

### Pi/firmware/device

- Unit/simulation: sensor conversion, filtering, state machine, checksum, config validation.
- Hardware-in-the-loop: encoder/IMU/driver/limit/e-stop, current fault, watchdog.
- Soak: nhiều giờ sample/buffer/reconnect, disk/power cycle.
- Fault injection: mất MQTT/backend/Pi/MCU sensor; duplicate/out-of-order/corrupt frame.
- Calibration repeatability và comparison với thiết bị/thước tham chiếu.

### AI/data

- Dataset schema/label validation, subject-wise split để tránh data leakage.
- Metrics theo label/person/device, không chỉ accuracy tổng.
- Confusion matrix, precision/recall/F1 và confidence calibration.
- Out-of-distribution/uncertain behavior.
- Model artifact hash, feature schema compatibility và regression set.

## 2. Test scenarios end-to-end tối thiểu

1. Patient register → consent → pair → calibration → exercise → completed summary.
2. Pair code expired/reused/brute-force.
3. Device offline trước start; app không hiển thị active.
4. Mất mobile/backend trong session; local safety vẫn hoạt động, dữ liệu sync sau.
5. Duplicate/out-of-order telemetry; summary không double-count và có gap flag.
6. E-stop/overcurrent trong session; local stop trước, session aborted, notification/audit sau.
7. Caregiver có scope xem; sau revoke bị deny ngay ở request tiếp theo.
8. Clinician sửa plan revision; session cũ vẫn hiển thị snapshot cũ.
9. AI timeout/fail/uncertain; summary cơ bản vẫn có và không tạo safety override.
10. Token refresh race/reuse; compromised refresh family bị revoke.
11. Text scale 200%, tiếng Việt dài, offline/error trên các màn hình chính.
12. Firmware/protocol incompatible; device report health được nhưng session bị chặn.

## 3. Observability

### Logs/traces

Structured JSON với `timestamp`, `level`, `service`, `environment`, `request_id`, `trace_id`, `route`, `status_code`, `duration_ms`, pseudonymous actor/device ID và error code. Trace xuyên API → outbox → worker → broker ack khi có thể.

### Metrics

Backend:

- Request rate/error/latency theo route template.
- DB pool saturation, query latency, transaction retry.
- MQTT connected devices, ingest batches/samples/bytes, duplicate/gap/quarantine.
- WebSocket connection/fan-out/drop.
- Outbox/job lag, retry/dead-letter.
- Session count/state/aborted reason.
- Notification delivery result; AI latency/failure/uncertain ratio.

Device fleet:

- Online/last-seen, firmware distribution, battery, calibration expiry.
- Sensor/motor fault, e-stop/overcurrent/watchdog rate.
- Buffer usage, upload lag/data loss, clock drift.

Không đặt email/name/patient ID raw làm metric label để tránh PII và cardinality.

## 4. Alert vận hành

| Mức | Điều kiện ví dụ | Owner |
|---|---|---|
| Page/high | Nhiều device critical fault bất thường, ingest outage, DB unavailable | On-call backend/device |
| Ticket/medium | Job dead-letter, firmware compatibility tăng, backup fail | Platform owner |
| Product review | AI uncertain/drift tăng, pre-flight fail tăng | AI/product/device |

Alert vận hành không thay thế patient safety notification. Runbook cần nêu impact, dashboard, query an toàn, mitigation, escalation và postmortem.

## 5. CI/CD quality gates

- Format/lint: `cargo fmt`, `clippy -D warnings` theo policy; `dart format`, `flutter analyze`.
- Unit/integration/contract tests.
- Migration clean + upgrade test; OpenAPI breaking-change check.
- Dependency advisory/license/secret scan.
- Build reproducible artifact, SBOM, signed checksum; environment promotion cùng artifact.
- Staging smoke test với device simulator trước production.
- Production migration có backup/rollback application plan; database migration ưu tiên expand/contract.

## 6. Environment

| Env | Mục đích | Dữ liệu |
|---|---|---|
| Local | Developer + simulator | Synthetic |
| Dev | Tích hợp liên tục | Synthetic/test devices |
| Staging | Release candidate/HIL | Pseudonymous controlled test |
| Production | Pilot/vận hành | Real, strict access/retention |

Không copy production DB xuống dev. Flavor mobile hiện có `dev/staging/production` phải map đúng API, bundle ID, analytics và signing riêng.

## 7. Roadmap triển khai

### Phase 0 — Safety và contracts

Deliverables:

- Chốt MCU/Pi responsibility, sensor/motor sides, protocol version và safe-state.
- Hazard analysis bản đầu, pre-flight checklist, approved limit profile process.
- JSON Schema/golden messages cho telemetry/event/state/intent.
- Device simulator phát happy/fault/offline sequences.
- OpenAPI skeleton và database migration baseline.

Exit: E-stop/limit/current protection được chứng minh local trong fault test; không còn đường raw cloud motor control.

### Phase 1 — Identity, Material 3 foundation, device pairing

- Refactor backend identity sang layered module + PostgreSQL + refresh rotation.
- Flutter M3 blue theme, common state/error/accessibility components.
- Profile/consent, device registry/pairing, reported health và calibration flow.
- Production config/secret/CORS/log redaction baseline.

Exit: onboarding → pair → device ready chạy end-to-end trên simulator và phần cứng test.

### Phase 2 — Exercise, plan và session core

- Versioned exercise catalog, plan/revision và snapshot.
- Prepare/pre-flight/start/stop session state machine.
- Patient home, exercise detail, pre-flight, live shell, result cơ bản.
- MQTT intent/ack và WebSocket state events.

Exit: một bài `sit_to_stand` hoàn chỉnh, offline app không phá session, device từ chối start sai điều kiện.

### Phase 3 — Telemetry, safety, progress

- Durable Pi buffer, batch ingest/dedup/gap/retention.
- Safety event/alert/notification/audit.
- Session aggregator, progress overview/history/charts.
- Caregiver relationship và read-only monitoring.

Exit: telemetry không double-count khi retry; critical event local-to-cloud được truy vết; revoke access test đạt.

### Phase 4 — AI assessment và clinician workflow

- Dataset/consent/label protocol, feature version và model registry.
- Baseline rule + Random Forest/Decision Tree được đánh giá subject-wise.
- Assessment async, explanation/uncertain, clinician review và plan editor.
- Model monitoring/regression/rollback.

Exit: model đạt tiêu chí được chuyên môn duyệt; AI failure không ảnh hưởng safety/session core.

### Phase 5 — Pilot hardening

- HIL/soak/fault/usability/accessibility/security testing.
- Backup restore, incident response, support/maintenance runbooks.
- Firmware rollout/rollback và fleet dashboard.
- Legal/privacy/safety approval cho pilot, training người hỗ trợ.

Exit: pilot readiness review ký bởi product, device, backend, QA, safety/clinical owner.

## 8. Vertical slice ưu tiên

Slice đầu tiên không nên làm toàn bộ screen/module rời rạc. Chọn `sit_to_stand`:

```text
pair device
  → calibration
  → published exercise/plan item
  → prepare/pre-flight
  → start + live aggregate
  → normal stop
  → telemetry aggregate
  → result/history
  → one warning + one e-stop fault path
```

Slice này kiểm tra được ranh giới mobile–backend–Pi–MCU trước khi nhân rộng catalog.

## 9. Ownership đề xuất

| Area | Primary owner | Review bắt buộc |
|---|---|---|
| Mechanical/actuator/safe-state | Hardware/control | Safety/clinical |
| MCU/Pi/protocol | Embedded/Pi | Backend + safety |
| Rust API/data/auth | Backend | Security + mobile |
| Flutter UX/accessibility | Mobile | Product + user research |
| Exercise/threshold | Clinical/product | Safety + device |
| Dataset/model | AI/data | Clinical + privacy |
| Release/incident | Tech lead/ops | Các owner liên quan |

Một người có thể kiêm nhiều vai trò trong team nhỏ, nhưng trách nhiệm review vẫn phải được ghi rõ.

## 10. Definition of Done cấp feature

- Acceptance criteria và out-of-scope rõ.
- Safety/privacy/security impact đã xem xét.
- Contract/schema/version và migration cập nhật.
- Happy, error, permission, offline/retry test đạt.
- UI có loading/content/empty/error/offline, semantics và Vietnamese copy.
- Logs/metrics/audit không lộ PII/secret; dashboard/runbook nếu feature vận hành quan trọng.
- Backward compatibility hoặc migration strategy có kiểm chứng.
- Tài liệu trong `codex/` cập nhật cùng thay đổi.

## 11. Quyết định còn mở

Các câu hỏi sau phải được chốt bằng ADR/biên bản trước phase tương ứng:

1. ESP32 hay STM32; Raspberry Pi/ROS 1 hiện tại có phù hợp production hay chuyển ROS 2/service nhẹ.
2. Kết nối Pi–MCU (CAN/UART), sample rate, batch encoding và buffer capacity.
3. Một hay hai bên hông/gối; heart-rate có trong MVP hay optional.
4. Safe-state theo cơ cấu thực, hard/soft limits và owner phê duyệt limit profile.
5. MQTT broker/deployment, AI chạy trong Rust worker hay service Python tách biệt.
6. Retention, nơi lưu trữ/region, điều khoản consent và quy trình pilot người thật.
7. Caregiver/clinician scope cụ thể và có dashboard web riêng hay mobile adaptive.
