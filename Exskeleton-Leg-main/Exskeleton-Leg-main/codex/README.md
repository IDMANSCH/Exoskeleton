# Exoskeleton Leg — Hồ sơ định hình dự án

Tài liệu trong thư mục này là nguồn tham chiếu thống nhất cho sản phẩm khung hỗ trợ vùng lưng, theo dõi khớp hông và hỗ trợ nhẹ khớp gối phục vụ tập phục hồi chức năng.

## Nguyên tắc nền tảng

1. **An toàn tại thiết bị:** vòng điều khiển động cơ, giới hạn góc/dòng và dừng khẩn cấp phải hoạt động cục bộ, không phụ thuộc Internet, ứng dụng hay backend.
2. **Hỗ trợ, không chẩn đoán:** AI và ứng dụng chỉ đánh giá động tác/gợi ý luyện tập; không thay thế bác sĩ và không tự thay đổi phác đồ điều trị.
3. **Dễ dùng cho người cao tuổi:** thao tác ít bước, chữ lớn, tương phản tốt, phản hồi âm thanh/rung và luôn có đường thoát an toàn.
4. **Contract-first:** mobile, backend và thiết bị tích hợp qua API/protocol có phiên bản; không chia sẻ trực tiếp cấu trúc database.
5. **Dữ liệu tối thiểu:** chỉ thu thập dữ liệu cần thiết, có đồng ý của người dùng, kiểm soát truy cập và thời hạn lưu trữ.

## Bản đồ tài liệu

| Tài liệu | Nội dung | Đối tượng chính |
|---|---|---|
| [01-product-scope.md](01-product-scope.md) | Tầm nhìn, persona, phạm vi MVP, yêu cầu chức năng | Product, toàn đội |
| [02-system-architecture.md](02-system-architecture.md) | Kiến trúc tổng thể, luồng dữ liệu, ranh giới an toàn | Tech lead, embedded, backend |
| [03-domain-modules.md](03-domain-modules.md) | Bounded context, module, ownership và quy tắc nghiệp vụ | Backend, mobile, QA |
| [04-backend-rust.md](04-backend-rust.md) | Layered architecture cho Rust/Axum, cấu trúc source, quy ước | Backend |
| [05-data-model.md](05-data-model.md) | Mô hình dữ liệu PostgreSQL, trạng thái, index và retention | Backend, data/AI |
| [06-api-contract.md](06-api-contract.md) | REST API v1, request/response, lỗi, phân quyền | Backend, mobile, QA |
| [07-device-realtime-protocol.md](07-device-realtime-protocol.md) | Telemetry, MQTT/WebSocket, offline sync, command an toàn | Embedded/Pi, backend, mobile |
| [08-mobile-screens.md](08-mobile-screens.md) | Navigation, màn hình, trạng thái và luồng UX | Mobile, product, design |
| [09-material3-design-system.md](09-material3-design-system.md) | Material 3, bảng màu xanh dương, typography, component | Mobile, design |
| [10-web-dashboard.md](10-web-dashboard.md) | Dashboard theo dõi cho caregiver, clinician và admin | Web/mobile, product |
| [11-safety-security-privacy.md](11-safety-security-privacy.md) | Safety rules, threat model, quyền riêng tư và audit | Toàn đội |
| [12-quality-roadmap.md](12-quality-roadmap.md) | Test strategy, observability, phase triển khai và DoD | Tech lead, QA, PM |
| [13-mobile-main-and-system-api-design.md](13-mobile-main-and-system-api-design.md) | Phase tiếp theo: main mobile shell, các page chính và API hệ thống MVP | Mobile, backend, product |
| [14-mobile-screen-blueprints-and-api-spec.md](14-mobile-screen-blueprints-and-api-spec.md) | Blueprint chi tiết từng màn hình điện thoại và API theo màn hình | Mobile, backend, design |

## Quy ước sử dụng

- Ngôn ngữ tài liệu là tiếng Việt; tên code, endpoint và schema dùng tiếng Anh.
- UUID là định danh công khai. Thời gian dùng UTC theo ISO 8601; ứng dụng hiển thị theo múi giờ người dùng.
- Đơn vị chuẩn: góc `degree`, vận tốc góc `degree/second`, nhịp tim `bpm`, dòng điện `mA`, thời lượng `second`.
- Endpoint public bắt đầu bằng `/api/v1`; payload dùng `snake_case`.
- Thay đổi API hoặc protocol phải cập nhật tài liệu tương ứng trước hoặc cùng pull request.
- Các giá trị ngưỡng trong tài liệu là cấu trúc dữ liệu, **không phải ngưỡng y khoa mặc định**. Ngưỡng thực tế phải được xác nhận bởi người có chuyên môn và kiểm thử trên thiết bị.

## Trạng thái hiện tại và kiến trúc đích

Repository hiện có:

- `Mobile App/`: Flutter, BLoC, AutoRoute, Dio/Retrofit, GetIt/Injectable.
- `Backend/`: Rust, Axum, Tokio; auth mẫu dùng repository in-memory.
- `Pi/`: ROS workspace và base node mẫu.

Kiến trúc trong bộ tài liệu này là **kiến trúc đích**. Việc chuyển đổi được thực hiện theo từng lát dọc, không yêu cầu viết lại toàn bộ ngay lập tức. Chi tiết thứ tự nằm trong `12-quality-roadmap.md`.
