# 10. Dashboard theo dõi

## 1. Mục tiêu và phạm vi

Dashboard dành cho caregiver, clinician và admin để theo dõi nhiều người tập, xem cảnh báo/tiến độ và quản lý kế hoạch trong phạm vi quyền. Dashboard không phải hệ thống cấp cứu, không chẩn đoán và **không có chức năng điều khiển motor trực tiếp**.

Trong MVP, dashboard có thể là adaptive web shell trong Flutter project hiện tại để tái sử dụng domain model, API client, localization và Material 3 theme. Feature code không phụ thuộc widget mobile; navigation/layout web tách riêng. Sau pilot chỉ tách thành web app riêng nếu bundle size, accessibility hoặc workflow dữ liệu dày chứng minh cần thiết.

## 2. Vai trò

| Vai trò | Landing page | Phạm vi |
|---|---|---|
| Caregiver | Người tập của tôi | Xem tổng quan/session/alert của patient đã đồng ý; acknowledge alert |
| Clinician | Danh sách phụ trách | Caregiver rights + tạo/publish plan, review assessment, clinical note theo policy |
| Admin | Vận hành | Account/device/catalog/audit/health; không mặc nhiên xem raw health data |

Role switch phải hiển thị context đang dùng. Backend authorize từng resource; ẩn menu không thay thế permission check.

## 3. Information architecture

```text
/dashboard
├─ /overview
├─ /patients
│  ├─ /:patientId/overview
│  ├─ /:patientId/plans
│  ├─ /:patientId/sessions
│  ├─ /:patientId/progress
│  └─ /:patientId/alerts
├─ /alerts
├─ /devices
│  └─ /:deviceId
├─ /exercises
│  └─ /:exerciseId/versions
├─ /notifications
├─ /audit                 # admin/authorized only
├─ /system-health         # admin/ops only
└─ /settings
```

Desktop dùng `NavigationRail` mở rộng hoặc permanent drawer; tablet dùng rail thu gọn; màn hình nhỏ chuyển sang navigation phù hợp và ẩn workflow chỉnh plan phức tạp nếu không đạt usability.

## 4. Màn hình caregiver/clinician

### `WD-01` Overview

Khối chính:

- Tóm tắt hôm nay: patient scheduled, completed, missed, active.
- Alert chưa acknowledge theo severity.
- Patient cần chú ý: session aborted, device offline lâu, adherence giảm.
- Recent activity feed có filter và thời gian.

Mọi số liệu có thời gian cập nhật; status realtime là hint, click vào detail lấy REST snapshot.

### `WD-02` Patient list

Columns: tên hiển thị, plan hôm nay, last session, adherence 7 ngày, device status, unresolved alert. Search/filter theo status/assignee; cursor pagination.

- Không hiển thị dữ liệu nhạy cảm không cần thiết như DOB đầy đủ/clinical note trong table.
- Row action chỉ `Xem chi tiết`; không đặt destructive action trong overflow table.
- Empty state phân biệt chưa được assign và filter không có kết quả.

### `WD-03` Patient overview

Header: patient identity tối thiểu, relationship/scope, device và last seen. Sections:

- Plan hôm nay và completion.
- 4 metric chính: active minutes, completed sessions, correctness, alert.
- Trend 4–8 tuần có data quality.
- Session gần đây.
- Alert đang mở.

Nếu consent/scope bị thu hồi, chuyển ngay sang access-revoked page và xóa cache nhạy cảm của context đó.

### `WD-04` Plan list/editor

List revision/status/validity/author. Editor dạng structured stepper:

1. Thông tin plan.
2. Chọn exercise version.
3. Lịch và target.
4. Assistance level/approved limit profile tương thích device.
5. Review diff và publish.

Autosave chỉ cho draft; publish cần server validation + confirm. Conflict version hiển thị bản hiện tại và cho reload/duplicate draft, không silent overwrite.

### `WD-05` Sessions

Table: start time, exercise, duration, status, completed/target, correctness, warning/critical, quality flag. Filter date/exercise/status; export chỉ khi có permission và audit.

Detail:

- Summary và snapshot version.
- Timeline session state/safety event.
- Chart trunk/hip/knee, chọn tối đa vài series, gap rõ ràng.
- Rule/ML assessment, confidence, model version, explanation codes.
- Technical tab raw/batch quality chỉ cho role phù hợp.

### `WD-06` Progress

Filter tuần/tháng/custom trong giới hạn; so sánh với chính patient theo thời gian, không xếp hạng giữa patient. Cards và chart:

- Adherence/completion.
- Correctness trend.
- ROM theo exercise/joint/side.
- Warning/critical frequency.
- Assistance level history.

Không vẽ đường trend khi thiếu denominator/chất lượng; dùng `Chưa đủ dữ liệu`.

### `WD-07` Alert center

Queue ưu tiên critical → warning → info; filter patient/type/status/time. Detail có nguồn, local action, session snapshot, acknowledgement và resolution history.

- `Acknowledge` nghĩa là đã xem, không nghĩa sự cố đã xử lý.
- `Resolve` chỉ role được phép, bắt buộc reason/note theo schema.
- Không có action resume motor/session từ alert.

## 5. Màn hình admin/operations

### `AD-01` Device fleet

Serial/model, assignment pseudonymous, online, firmware/protocol, calibration, fault, last seen. Actions có quyền: provision/revoke credential, maintenance lock, approved firmware rollout workflow. Không có raw actuator control.

### `AD-02` Exercise catalog

Draft/published/retired versions, capability/target schema, localized instruction/voice asset. Published version bất biến; retire không làm mất lịch sử session.

### `AD-03` Account và role

Search tối thiểu, status, roles, relationship summary. Role change và deactivate yêu cầu lý do, confirm, re-auth nếu policy yêu cầu và audit.

### `AD-04` Audit explorer

Filter actor/action/resource/time/request ID. Metadata được redact; export giới hạn. Audit row không sửa/xóa từ UI.

### `AD-05` System health

Fleet online, ingest lag/gap/quarantine, outbox/job backlog, notification/AI failure, version distribution. Đây là operational dashboard, không trộn patient identity.

## 6. Responsive layout

| Breakpoint định hướng | Navigation | Content |
|---|---|---|
| `< 600` | Bottom/compact; read-mostly | Single column, table chuyển card/list |
| `600–1199` | Navigation rail | 8–12 column adaptive grid |
| `>= 1200` | Extended rail/drawer | Max content width hợp lý; list-detail có thể song song |

Breakpoint cuối dựa trên available width, không nhận diện device. Dialog lớn chuyển side sheet/full page khi form phức tạp.

## 7. Material 3 dashboard rules

- Dùng token trong `09-material3-design-system.md`; primary blue cho navigation/action.
- Data table dùng header rõ, row density standard/comfortable mặc định; không ép compact cho người lớn tuổi.
- Status dùng icon + label; color semantic không đứng một mình.
- Filter hiển thị active state và nút `Xóa bộ lọc`.
- Charts có unit, legend, tooltip keyboard, data table/text alternative.
- Primary action mỗi page; bulk action bị giới hạn và confirm khi nhạy cảm.
- Side panel/detail không che critical alert context.

## 8. Realtime và cache

- WebSocket cập nhật badge/status/session live aggregate, có `resource_version`.
- REST là source of truth; reconnect/gap luôn refetch.
- Query cache key gồm actor role, patient/resource, filter và API version.
- Khi logout/role switch/revoke relationship, purge cache nhạy cảm tương ứng.
- Browser storage không giữ raw telemetry/token dài hạn; refresh token strategy cho web cần quyết định bảo mật riêng, ưu tiên secure HttpOnly cookie nếu backend web flow hỗ trợ.

## 9. Export và in báo cáo

- Export CSV/PDF là background job, có permission, purpose, audit, TTL download và notification khi xong.
- PDF ghi patient, time range/timezone, metric definition, data quality, plan/model/algorithm version cần thiết.
- Report ghi rõ đây là dữ liệu hỗ trợ theo dõi, không phải chẩn đoán.
- Không cho export vượt patient scope hoặc date range giới hạn.

## 10. Acceptance criteria chung

- Keyboard-only và screen reader thực hiện được navigation, filter, table, dialog, chart alternative.
- Deep link unauthorized không lộ resource existence/details.
- Filter/pagination giữ trong URL để refresh/share nội bộ hợp lệ.
- Version conflict không làm mất draft.
- Revoke permission làm request tiếp theo bị từ chối và xóa context cache.
- Realtime disconnect hiển thị stale/last updated, không hiển thị online giả.
- Không màn hình nào có raw motor command hoặc bỏ qua device pre-flight.

