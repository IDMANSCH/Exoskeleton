# Cá nhân hóa quy trình động tác

Hệ thống hiện dùng quy trình dạng dữ liệu:

`Flutter app → REST API/PostgreSQL → BLE chunks → Pi SafetyGateway → UART → ESP32`

App lấy payload đã biên dịch từ endpoint `dispatch`, chia thành các gói BLE
`routine_begin`, `routine_chunk`, `routine_commit`, sau đó chờ chính ESP32 đưa
toàn bộ xy lanh về HOME và phản hồi trước khi hiển thị trạng thái đang chạy.

## Dữ liệu một bước

```json
{
  "label": "Nâng đùi cao",
  "motor": "C2",
  "direction": "OUT",
  "duration_ms": 5000,
  "rest_after_ms": 1000,
  "repeat_count": 1
}
```

Motor hợp lệ: `C1` gối phải, `C2` đùi phải, `C3` gối trái, `C4` đùi trái.
Chiều `OUT` là co/nâng, `IN` là duỗi/hạ và `STOP` là dừng. Server lưu cả
`definition_json` đã biên dịch để thay đổi danh mục động tác không làm thay đổi
các bài đã lưu.

## Rule trạng thái khớp

- Mặc định mọi khớp bắt đầu ở `IN`: gối duỗi, đùi hạ.
- Một khớp đã `OUT` thì không được `OUT` tiếp; phải `IN` trước.
- Một khớp đã `IN` thì không được `IN` tiếp; tránh gửi lệnh vô nghĩa.
- Đảo chiều cùng một khớp cần nghỉ ít nhất 700 ms.
- Nếu người dùng quên bước kết thúc, server tự thêm bước `IN` 7 giây về vị trí ban đầu cho mọi khớp đã dùng.
- SafetyGateway kiểm tra lại các rule này trước khi cho phép Pi gửi UART.

## Chế độ chân

- `ONE_LEG`: chọn một chân trái hoặc phải; mọi bước khác chân đều bị từ chối.
- `TWO_LEG_ALTERNATING`: người dùng tạo trọn flow cho chân bắt đầu. Server tự
  mirror toàn bộ flow (`C1→C3`, `C2→C4`) sau khi chân đầu đã về HOME.

## API

- `GET /api/v1/motion-library`: các ô động tác/biến thể được phép chọn.
- `GET /api/v1/patients/{patientId}/motion-routines`: danh sách bài đã lưu.
- `POST /api/v1/patients/{patientId}/motion-routines`: tạo bài.
- `GET /api/v1/patients/{patientId}/motion-routines/{routineId}`: xem bài.
- `POST /api/v1/patients/{patientId}/motion-routines/{routineId}/dispatch`: lấy payload `routine_command` để gửi qua BLE.

Ví dụ tạo bài “Nâng đùi cao → Đá gối cao → Hạ đùi → Duỗi gối”:

```json
{
  "name": "Đứng bước phải nâng cao",
  "repetitions": 5,
  "steps": [
    {"label":"Nâng đùi cao","motor":"C2","direction":"OUT","duration_ms":5000,"rest_after_ms":1000,"repeat_count":1},
    {"label":"Co gối","motor":"C1","direction":"OUT","duration_ms":2000,"rest_after_ms":1000,"repeat_count":1},
    {"label":"Đá gối cao","motor":"C1","direction":"IN","duration_ms":2500,"rest_after_ms":1000,"repeat_count":1},
    {"label":"Hạ đùi","motor":"C2","direction":"IN","duration_ms":3000,"rest_after_ms":1000,"repeat_count":1}
  ]
}
```

Tất cả lệnh đảo chiều cùng một xy lanh phải có nghỉ tối thiểu 700 ms. API,
SafetyGateway và ESP32 đều kiểm tra lại giới hạn này. Start và Stop đều chạy
HOME 7 giây; Stop hủy routine đang chạy trước khi phát lệnh HOME.
