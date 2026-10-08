# 01. Phạm vi sản phẩm

## 1. Tuyên bố sản phẩm

Exoskeleton Leg là hệ thống hỗ trợ tập phục hồi tại nhà hoặc cơ sở chăm sóc cho người cao tuổi/người suy giảm vận động nhẹ đến trung bình. Hệ thống giúp giữ tư thế lưng, đo chuyển động hông–gối, hỗ trợ nhẹ khớp gối, cảnh báo bất thường và ghi nhận tiến độ.

Sản phẩm không phải thiết bị tự hành, không thay thế sức người hoàn toàn, không tự chẩn đoán bệnh và không cho phép cloud điều khiển động cơ theo vòng kín.

## 2. Người dùng và quyền

| Vai trò | Nhu cầu | Quyền chính |
|---|---|---|
| `patient` | Tập dễ hiểu, an toàn, xem tiến độ cá nhân | Quản lý hồ sơ bản thân, ghép thiết bị, bắt đầu/kết thúc buổi tập, xem dữ liệu của mình |
| `caregiver` | Theo dõi người thân và nhận cảnh báo | Xem bệnh nhân đã chấp thuận, lịch sử/tổng hợp, nhận thông báo; không sửa ngưỡng chuyên môn |
| `clinician` | Theo dõi và cấu hình chương trình tập | Tạo/chỉnh kế hoạch cho bệnh nhân được phân công, xem dữ liệu chi tiết, ghi chú đánh giá |
| `admin` | Vận hành hệ thống | Quản lý tài khoản, thiết bị, catalog bài tập và audit; không mặc nhiên xem dữ liệu sức khỏe chi tiết |
| `device` | Gửi dữ liệu và nhận cấu hình đã ký | Chỉ truy cập tài nguyên gắn với chính thiết bị |

Một tài khoản có thể có nhiều vai trò. Quan hệ caregiver/clinician với patient luôn cần trạng thái đồng ý hoặc phân công hợp lệ.

## 3. Giá trị cốt lõi

- Phản hồi tư thế ngay tại chỗ, kể cả khi mất mạng.
- Đo được tiến độ bằng số liệu: thời gian, số lần, ROM hông/gối, tỷ lệ đúng, số cảnh báo.
- Bài tập ngắn, rõ ràng, có giọng nói tiếng Việt.
- Người thân/chuyên viên chỉ thấy đúng dữ liệu được cho phép.
- Có dữ liệu gốc và kết quả AI đủ truy vết để kiểm chứng.

## 4. Phạm vi MVP

### 4.1 Thiết bị

- IMU vùng lưng; encoder hông trái/phải và gối trái/phải theo cấu hình phần cứng thực tế.
- Đọc công tắc giới hạn, nút dừng khẩn cấp, trạng thái driver và dòng động cơ.
- Ba mức hỗ trợ danh nghĩa: `low`, `medium`, `high`; giá trị lực/dòng thật do firmware cấu hình và khóa trong giới hạn an toàn.
- Cảnh báo tại chỗ bằng rung/còi/giọng nói.
- Buffer telemetry khi mất mạng và đồng bộ lại theo thứ tự.
- Calibration có hướng dẫn và lưu version.

### 4.2 Ứng dụng mobile

- Đăng nhập/đăng ký, hồ sơ người tập và đồng ý sử dụng dữ liệu.
- Ghép nối, kiểm tra thiết bị và calibration.
- Danh sách kế hoạch/bài tập; hướng dẫn trước khi tập.
- Màn hình buổi tập thời gian thực: tư thế, số lần, nhịp, mức hỗ trợ, cảnh báo.
- Kết quả sau buổi tập và lịch sử ngày/tuần/tháng.
- Liên kết người chăm sóc; thông báo khẩn cấp.
- Chế độ chữ lớn, tiếng Việt mặc định, có tiếng Anh.

### 4.3 Backend/dashboard data

- Identity, role và quan hệ patient–caregiver–clinician.
- Device registry, pairing và health status.
- Exercise catalog, plan và session.
- Nhận telemetry/events, tạo session summary và progress report.
- Ghi nhận AI assessment có model version.
- Notification, emergency event và audit log.

### 4.4 AI phiên bản đầu

- Phân loại tập đặc trưng dạng bảng/window bằng Decision Tree hoặc Random Forest.
- Nhãn MVP: `correct`, `excessive_forward_lean`, `excessive_left_lean`, `excessive_right_lean`, `insufficient_knee_rom`, `excessive_hip_flexion`, `too_fast`, `unstable`.
- Kết quả gồm label, confidence, model version và reason/features chính.
- Rule engine an toàn luôn có ưu tiên cao hơn AI; confidence thấp trả `uncertain`, không tự suy diễn.

## 5. Ngoài phạm vi MVP

- Chẩn đoán, kê đơn hoặc tự điều chỉnh phác đồ y khoa.
- Leo cầu thang, chạy, nâng toàn bộ cơ thể hoặc khung xương toàn thân.
- Điều khiển động cơ trực tiếp từ Internet/mobile.
- Khóa cứng khớp tự động dựa trên kết quả AI.
- Video/camera nhận diện tư thế.
- Thanh toán, bảo hiểm, bệnh án điện tử và tích hợp bệnh viện.
- Huấn luyện model trực tiếp trên dữ liệu production chưa được ẩn danh/duyệt.

## 6. Nhóm chức năng và tiêu chí chấp nhận cấp sản phẩm

| Epic | Kết quả cần đạt |
|---|---|
| Onboarding | Patient hiểu cảnh báo y tế, chấp thuận dữ liệu và hoàn tất hồ sơ tối thiểu |
| Pairing | Chỉ mã ghép nối dùng một lần mới liên kết được thiết bị; hiển thị rõ firmware và trạng thái cảm biến |
| Pre-flight check | Không thể bắt đầu nếu e-stop đang bật, sensor/limit switch lỗi, pin quá thấp hoặc chưa calibration |
| Guided exercise | Hiển thị/đọc tên bài, mục tiêu, số lần/thời lượng và điều kiện dừng |
| Live session | Dữ liệu chính cập nhật mượt; mất mạng không làm mất chức năng an toàn cục bộ |
| Alert | Cảnh báo an toàn có mức độ, nguyên nhân, thời điểm và hành động đã thực hiện |
| Emergency | E-stop dừng hỗ trợ cục bộ trước; sau đó mới gửi sự kiện/thông báo khi có kết nối |
| Progress | Tổng hợp được thời gian, completion, correctness, ROM và xu hướng theo tuần |
| Sharing | Patient có thể cấp/thu hồi quyền caregiver; mọi truy cập nhạy cảm có audit |

## 7. Chỉ số sản phẩm

- Tỷ lệ hoàn tất onboarding và ghép thiết bị.
- Tỷ lệ buổi tập hoàn thành; số lần bỏ dở theo nguyên nhân.
- Tỷ lệ thời gian ở tư thế đúng và ROM đạt mục tiêu.
- Số cảnh báo theo 100 phút tập, phân tách cảnh báo thật/nhầm khi có nhãn kiểm chứng.
- Độ trễ phản hồi **tại thiết bị** và độ trễ hiển thị trên app được đo riêng.
- Tỷ lệ upload telemetry thành công, duplicate rate và thời gian đồng bộ sau offline.
- Crash-free sessions của mobile/backend/device agent.

Không dùng engagement đơn thuần để khuyến khích người dùng tập vượt kế hoạch.

## 8. Quy tắc nghiệp vụ quan trọng

1. Một `training_session` thuộc đúng một patient, một device và một plan item/exercise version.
2. Chỉ một session `active` trên một device tại một thời điểm.
3. Chỉ thiết bị đã pair và chưa revoke mới được gửi telemetry.
4. Session chỉ bắt đầu khi pre-flight check `passed` và người dùng xác nhận sẵn sàng.
5. `emergency_stop`, `limit_switch`, `overcurrent` hoặc sensor critical fault buộc thiết bị chuyển sang trạng thái hỗ trợ an toàn; backend chỉ ghi nhận hậu kiểm.
6. Sửa plan không làm thay đổi session đã hoàn thành; session giữ snapshot/version cấu hình lúc bắt đầu.
7. Xóa tài khoản là quy trình soft-delete + retention; audit và dữ liệu bắt buộc pháp lý được xử lý theo policy riêng.
8. AI assessment không được ghi đè raw telemetry hay safety event.

## 9. Giả định cần xác nhận trước pilot

- Cấu hình cảm biến/động cơ một bên hay hai bên.
- Vi điều khiển chính (ESP32/STM32), vai trò Raspberry Pi và phiên bản ROS.
- Chu kỳ lấy mẫu, dung lượng buffer và thời lượng pin mục tiêu.
- Ngưỡng ROM, tốc độ, nhịp tim, quá dòng theo từng đối tượng/bài tập.
- Đối tượng chịu trách nhiệm phê duyệt bài tập và ngưỡng an toàn.
- Quy định lưu trữ dữ liệu sức khỏe áp dụng tại thị trường triển khai.

