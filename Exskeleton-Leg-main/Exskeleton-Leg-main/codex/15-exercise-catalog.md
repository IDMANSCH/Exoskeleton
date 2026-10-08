# 15. Exercise catalog cho Exoskeleton Leg

## Mục tiêu

Catalog hiện tại ưu tiên bài tập chi dưới cấp độ beginner, tập trung vào kiểm
soát cơ đùi, gối, hông, bắp chân, chuyển tư thế và biên độ vận động. Đây là
catalog kỹ thuật để chuyên viên chọn/duyệt; không phải chẩn đoán hoặc đơn
điều trị tự động.

## Bài tập đã seed

| Code | Bài tập | Nhóm | Điểm tựa | Mục tiêu mặc định |
|---|---|---|---:|---|
| `sit_to_stand` | Đứng lên và ngồi xuống | strength | Có | 2 × 8 |
| `supported_knee_raise` | Nâng gối có hỗ trợ | mobility | Có | 2 × 8 mỗi bên |
| `seated_knee_extension` | Duỗi gối khi ngồi | mobility | Không | 2 × 10 mỗi bên |
| `heel_raises` | Nhón gót có điểm tựa | strength | Có | 2 × 8 |
| `straight_leg_raise` | Nâng chân thẳng | strength | Không | 2 × 8 mỗi bên |
| `heel_slides` | Trượt gót chân | mobility | Không | 2 × 10 mỗi bên |
| `quad_set` | Siết cơ đùi tĩnh | strength | Không | 2 × 10 |
| `supported_hip_extension` | Duỗi hông có điểm tựa | strength | Có | 2 × 8 mỗi bên |

Các mục tiêu trên chỉ là seed để môi trường development có dữ liệu hiển thị;
clinician phải xác nhận số set/repetition, biên độ, bên chân, mức hỗ trợ và
điều kiện dừng trước khi publish plan cho bệnh nhân.

## Cấu trúc dữ liệu

Migration `V202608310003__expand_leg_exercise_catalog.sql` bổ sung cho bảng
`exercises`:

- `name_key`, `description_key`, `instructions_key`, `safety_key`: khóa i18n,
  không lưu bản dịch trực tiếp trong UI.
- `difficulty`: hiện seed `beginner`.
- `requires_support`: bắt buộc UI/clinician kiểm tra điểm tựa trước bài đứng.
- `active`: chỉ catalog active mới được trả bởi API.

API:

- `GET /api/v1/exercises`: catalog active.
- `GET /api/v1/exercises/{exercise_id}`: chi tiết một bài.
- Plan item trả kèm toàn bộ exercise keys để mobile hiển thị đúng ngôn ngữ.

## Nguyên tắc an toàn

- Luôn giữ bài tập trong biên độ thoải mái do chuyên viên chỉ định.
- Bài đứng phải có ghế/bàn/điểm tựa chắc chắn khi cần; không tự suy luận rằng
  exoskeleton đã thay thế yêu cầu thăng bằng.
- Dừng khi đau tăng, chóng mặt, yếu đột ngột hoặc mất an toàn; chuyển sang
  chuyên viên/y tế khi cần.
- Không tự động tăng tải, thêm tạ, đổi mức hỗ trợ hay publish plan từ catalog.

## Nguồn tham khảo y khoa

Catalog chọn các dạng bài được mô tả trong tài liệu vật lý trị liệu công khai:

- Cambridge University Hospitals, [Knee exercises](https://www.cuh.nhs.uk/patient-information/knee-exercises/): sit-to-stand, heel raise, standing knee flexion và straight-leg raise.
- AAOS OrthoInfo, [Knee Conditioning Program](https://orthoinfo.aaos.org/globalassets/pdfs/2023-rehab_knee.pdf): straight-leg raise và nguyên tắc tiến triển có kiểm soát.
- NHS, [Strength and flexibility exercise safety](https://www.nhs.uk/live-well/exercise/strength-and-flex-exercise-plan-how-to-videos/): cần hỏi chuyên gia khi có chấn thương/bệnh nền hoặc sau phẫu thuật, và dừng khi đau hoặc không khỏe.

Các nguồn trên chỉ hỗ trợ việc chọn dạng bài phổ biến; chúng không thay thế
đánh giá lâm sàng cho từng bệnh nhân.
