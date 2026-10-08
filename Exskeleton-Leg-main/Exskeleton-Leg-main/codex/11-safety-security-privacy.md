# 11. An toàn, bảo mật và quyền riêng tư

## 1. Phạm vi trách nhiệm

Tài liệu này là baseline kỹ thuật, không phải chứng nhận thiết bị y tế hay tư vấn pháp lý. Trước thử nghiệm với người thật, đội dự án phải có đánh giá rủi ro/hazard analysis, quy trình thử nghiệm, phê duyệt chuyên môn và yêu cầu pháp lý phù hợp thị trường.

## 2. Safety architecture

Thứ tự ưu tiên:

1. Mạch/phần cứng an toàn: e-stop, current/limit protection, mechanical stop.
2. MCU firmware: watchdog, range/rate/current check, safe-state.
3. Pi local supervisor: sensor health, session state, approved configuration.
4. Backend rules/monitoring.
5. Mobile UX/notification.
6. AI assessment.

Lớp dưới không phụ thuộc lớp trên để thực hiện chức năng an toàn. AI không bao giờ được quyền ghi đè hard limit, bỏ qua e-stop hoặc tự tăng assistance.

## 3. Safe states

Safe-state vật lý phải được kỹ sư cơ khí/điện/điều khiển xác định theo hazard; không mặc định “motor off” luôn an toàn trong mọi cơ cấu. Hệ thống phần mềm biểu diễn tối thiểu:

- `normal_assistance`
- `reduced_assistance`
- `assistance_disabled`
- `emergency_stopped`
- `maintenance_locked`

Transition critical được log; reset yêu cầu điều kiện vật lý + pre-flight, không chỉ bấm trên app.

## 4. Hazard register khởi đầu

| Hazard | Trigger ví dụ | Control/prevention | Detection/evidence |
|---|---|---|---|
| Chuyển động vượt ROM | Encoder lỗi, config sai | Mechanical stop, firmware hard limit, signed approved profile | Encoder plausibility, limit switch, event |
| Lực hỗ trợ quá cao | Driver/config lỗi | Current limit phần cứng/driver, firmware cap | Current sensor, overcurrent event |
| Chuyển động ngoài ý muốn | Stale/duplicate command | Không có raw cloud command, intent expiry/idempotency, local state machine | Intent/event log |
| Mất thăng bằng | Tư thế bất ổn, tập quá sức | Bài phù hợp, người hỗ trợ ở pilot, warning/stop condition | IMU/rule + user stop |
| Sensor sai/đứt | Dây/encoder/IMU fault | Pre-flight, redundancy/plausibility, fail-safe | Health state, invalidity mask |
| Mất nguồn/mạng | Pin thấp, Wi-Fi lỗi | Local loop, battery threshold, durable buffer | Heartbeat/last seen |
| Quá nhiệt | Motor/driver tải lâu | Thermal/current/time cap nếu phần cứng hỗ trợ | Temperature/driver fault |
| Kẹt cơ khí/dây đeo | Sai lắp hoặc biến dạng | Hướng dẫn lắp, inspection, quick release | User check/maintenance log |
| Cảnh báo không nhận biết | Khiếm thính/thị lực, app đóng | Multimodal local feedback, caregiver flow | Alert delivery/local action |
| Dùng sai đối tượng/bài | Device share/plan sai | Patient-device assignment, version snapshot, pre-flight identity confirmation | Audit/session snapshot |

Hazard register chính thức cần severity × probability, residual risk, verification method, owner và trạng thái phê duyệt.

## 5. Điều kiện chặn bắt đầu session

- E-stop active hoặc chưa physical reset.
- Required sensor/encoder/limit switch không healthy.
- Calibration thiếu, hết hạn hoặc sai patient/device.
- Firmware/protocol không tương thích.
- Pin dưới ngưỡng được phê duyệt cho bài.
- Motor/driver fault hoặc maintenance lock.
- Device đã có session active.
- Config signature/hash/version không hợp lệ.
- Local clock/storage/queue fault ở mức không đáp ứng evidence policy.
- Patient chưa xác nhận checklist môi trường và trạng thái sức khỏe theo protocol pilot.

Backend có thể chặn thêm nhưng không được bỏ qua block từ device.

## 6. Emergency workflow

- Nút vật lý dễ tiếp cận, có nhãn/feedback, không phụ thuộc touchscreen.
- E-stop tác động local trước mọi network operation.
- Event critical lưu append-only với snapshot; mất Internet sẽ upload sau.
- Thông báo caregiver là best-effort, không được quảng bá như dịch vụ cấp cứu nếu chưa có hạ tầng/SLA tương ứng.
- App cung cấp nút gọi emergency contact/số phù hợp khu vực; không tự gọi nếu chưa có consent và product/legal decision.
- Sau sự cố: không resume session cũ, kiểm tra phần cứng, ghi resolution và tạo session mới sau pre-flight.

## 7. Security goals

- **Confidentiality:** chỉ actor được phép xem dữ liệu sức khỏe/telemetry.
- **Integrity:** không sửa được plan/config/telemetry/safety event không có quyền hoặc không bị phát hiện.
- **Availability:** lỗi cloud không phá local safety; hệ thống chống abuse cơ bản.
- **Authenticity:** backend biết đúng user/device; device biết config/intent từ backend hợp lệ.
- **Traceability:** hành động nhạy cảm có audit/request/actor/version.

## 8. Threat model và control

| Threat | Control bắt buộc |
|---|---|
| Đoán pairing code | TTL ngắn, one-time, rate limit, attempts cap, lưu hash |
| Device giả gửi telemetry | Per-device cert/credential, TLS, ACL topic, rotation/revoke |
| Replay intent/config | Message ID, monotonic version, expiry, signature, state validation |
| IDOR xem patient khác | Resource-level policy trong use case, integration test mọi endpoint |
| Token bị lấy | Access TTL ngắn, refresh rotation, secure storage, revoke, không log |
| SQL injection | SQLx bind parameters, allowlist sort/filter, validation |
| Broker topic escape | Server-side ACL exact topic, không tin client-provided device ID |
| Firmware/config downgrade | Signed artifact/config, version policy, rollback chỉ qua controlled procedure |
| Supply-chain dependency | Lockfile, advisory scan, SBOM/release, review dependency |
| Log lộ PII/secret | Structured allowlist logging, redaction test, restricted retention/access |
| Notification lộ sức khỏe trên lock screen | Generic copy theo preference; mở app mới xem chi tiết |
| DoS ingest | Per-device quota, payload limit, backpressure, quarantine malformed batch |

## 9. Data classification

| Class | Ví dụ | Xử lý |
|---|---|---|
| Public | Exercise marketing copy | Có thể public |
| Internal | Build/version, aggregate ops metric | Staff access |
| Confidential | Email, DOB, emergency contact, relationship | Encrypt transit/at rest, least privilege |
| Sensitive health | Telemetry, ROM, heart rate, alerts, assessment | Consent/purpose limitation, strict access/audit/retention |
| Secret | Password, token, private key, provider credential | Secret manager/secure enclave; không log/analytics |

## 10. Privacy rules

- Consent essential service tách khỏi optional analytics/model training.
- Thu thập tối thiểu; không thu heart rate nếu phần cứng/feature/consent không dùng.
- Patient xem ai có quyền và thu hồi caregiver access.
- Export dữ liệu có xác thực lại, link TTL ngắn và audit.
- Delete workflow nêu rõ dữ liệu xóa, ẩn danh, giữ theo nghĩa vụ nào.
- Dataset AI phải de-identify/pseudonymize, tách key, có dataset/version/consent lineage.
- Không dùng production telemetry để train model mặc định.
- Notification lock screen không ghi chi tiết như `quá dòng khớp gối của ông A` nếu chưa opt-in.

## 11. Logging và audit

Application log được phép có: request ID, actor/device pseudonymous ID, route template, status, latency, stable error code, trace ID. Không log request body mặc định cho auth/profile/telemetry.

Audit bắt buộc cho:

- Login security events, role change, account deactivate.
- Grant/revoke relationship/consent.
- Pair/unpair/revoke device.
- Create/publish/change plan/limit profile/config.
- Start/abort/resolve critical event.
- Xem/export/xóa dữ liệu nhạy cảm theo policy.
- Approve/retire model version.

Audit append-only, time synchronized và quyền đọc riêng.

## 12. Release security checklist

- Không có secret hard-code; cấu hình dev/staging/prod tách biệt.
- TLS cho API/MQTT; production CORS allowlist.
- Dependency/advisory, secret và container scan trong CI.
- Rate/payload limit cho auth, pairing, ingest và export.
- Backup/restore đã thử; credential rotation/revoke đã thử.
- Pen-test hoặc security review tập trung auth, IDOR, broker ACL và replay trước pilot.
- Mobile certificate validation, secure storage và screenshot/background privacy cho màn hình nhạy cảm được đánh giá.
- Debug endpoints/ROS topics không public trong production.
