# 08. Mobile app: cấu trúc và màn hình

## 1. Định hướng UX

- Tiếng Việt mặc định, câu ngắn và dùng động từ rõ ràng.
- Luồng tập chính tối đa: **Trang chủ → Chọn bài → Kiểm tra → Bắt đầu**.
- Một màn hình một mục tiêu; hành động chính nổi bật và cố định khi cần.
- Người dùng không cần đọc biểu đồ trong lúc tập; ưu tiên số lần, tư thế và chỉ dẫn âm thanh.
- Cảnh báo critical chiếm ưu tiên, có icon + text + âm thanh/rung; không chỉ đổi màu.
- App không hiển thị rằng thiết bị đã bắt đầu/dừng cho tới khi nhận xác nhận từ device/backend.

## 2. App shell theo vai trò

### Patient navigation bar

1. `home` — Hôm nay
2. `training` — Bài tập
3. `progress` — Tiến độ
4. `device` — Thiết bị
5. `profile` — Cá nhân

Trên màn hình hẹp có 5 `NavigationDestination`; label luôn hiển thị. Không dùng FAB cho emergency vì emergency vật lý phải luôn là kênh chính.

### Caregiver/clinician navigation bar

1. `patients` — Người tập
2. `alerts` — Cảnh báo
3. `notifications` — Thông báo
4. `profile` — Cá nhân

Nếu user có nhiều role, chuyển chế độ trong account menu với nhãn rõ `Chế độ người tập` / `Chế độ theo dõi`; không trộn dữ liệu hai vai trò trên cùng home.

## 3. Route map

```text
/
├─ /onboarding
│  ├─ /welcome
│  ├─ /safety-notice
│  ├─ /consent
│  └─ /profile-setup
├─ /auth/login
├─ /auth/register
├─ /patient
│  ├─ /home
│  ├─ /training
│  │  ├─ /exercise/:id
│  │  ├─ /session/prepare
│  │  ├─ /session/:id/live
│  │  └─ /session/:id/result
│  ├─ /progress
│  │  └─ /session/:id
│  ├─ /device
│  │  ├─ /pair
│  │  ├─ /calibrate
│  │  └─ /diagnostics
│  └─ /profile
│     ├─ /care-network
│     ├─ /notifications
│     ├─ /accessibility
│     ├─ /privacy
│     └─ /help
└─ /care
   ├─ /patients
   ├─ /patients/:id/overview
   ├─ /patients/:id/plan
   ├─ /patients/:id/sessions/:sessionId
   ├─ /alerts
   └─ /profile
```

AutoRoute guards kiểm tra login và active role. Authorization thật vẫn ở backend; guard chỉ phục vụ UX.

## 4. Inventory màn hình

### A. Onboarding và auth

| ID | Màn hình | Nội dung/Hành động | Trạng thái bắt buộc |
|---|---|---|---|
| `OB-01` | Chào mừng | Giá trị sản phẩm, chọn ngôn ngữ, `Bắt đầu` | Default |
| `OB-02` | Lưu ý an toàn | Không thay thế bác sĩ, e-stop, điều kiện dừng; xác nhận đã đọc | Scroll + confirm; không pre-check consent |
| `OB-03` | Đồng ý dữ liệu | Tách essential, analytics, AI training consent | Grant/decline từng mục không bắt buộc |
| `OB-04` | Hồ sơ ban đầu | Tên, ngày sinh, timezone, mức vận động; emergency contact có thể thêm sau | Validation/submit/error |
| `AU-01` | Đăng nhập | Email, mật khẩu, quên mật khẩu | Idle/loading/error/offline |
| `AU-02` | Đăng ký | Field tối thiểu, password rules hiển thị trước | Validation/success |
| `AU-03` | Khôi phục mật khẩu | Email và màn hình xác nhận trung tính | Rate limit/success |

Không yêu cầu clinical notes hoặc dữ liệu không cần thiết trong onboarding.

### B. Patient home và bài tập

| ID | Màn hình | Khối chính | Primary action |
|---|---|---|---|
| `PH-01` | Hôm nay | Lời chào; device status; bài kế tiếp; tiến độ hôm nay; cảnh báo cần xem | `Bắt đầu bài tập` |
| `TR-01` | Danh sách bài | `Hôm nay`, `Tất cả`; card bài có thời lượng/số lần, difficulty, planned status | Chọn bài |
| `TR-02` | Chi tiết bài | Mục tiêu, minh họa, các bước, vùng vận động, mức hỗ trợ, cảnh báo dừng | `Chuẩn bị tập` |
| `TR-03` | Chuẩn bị/pre-flight | Kết nối, pin, cảm biến, e-stop, calibration, không gian an toàn; checklist realtime | `Tôi đã sẵn sàng` khi tất cả passed |
| `TR-04` | Calibration | Video/illustration từng bước, giữ tư thế, progress | `Bắt đầu hiệu chỉnh` / `Thử lại` |

Home states:

- Device ready: card xanh dương nhạt, text `Thiết bị sẵn sàng`.
- Offline: neutral/warning card, hướng dẫn bật device/kết nối.
- Critical unresolved: banner đỏ có tên sự cố và hành động xem chi tiết; không che nút gọi hỗ trợ.
- Không có plan: gợi ý bài self-guided đã được duyệt hoặc liên hệ chuyên viên, không tự tạo target y khoa.

### C. Live session

`TR-05` là màn hình ưu tiên tập trung, không dùng bottom navigation trong lúc active.

Layout dọc:

1. Top app bar: tên bài, trạng thái kết nối/pin nhỏ nhưng đọc được.
2. Hero state: icon cơ thể + `Tư thế tốt` / chỉ dẫn sửa tư thế.
3. Metric chính: số lần `6 / 16` hoặc timer; chữ lớn.
4. Nhịp: `Chậm lại`, `Đúng nhịp`, `Giữ 3 giây`.
5. Joint summary đơn giản; biểu đồ raw ẩn khỏi patient live screen.
6. Audio control: giọng nói, âm lượng; nút pause nếu exercise cho phép.
7. Bottom actions: `Tạm dừng` và `Kết thúc`; hold-to-confirm cho kết thúc giữa chừng.

State behavior:

| State | UI |
|---|---|
| `intent_pending` | Progress + `Đang chờ thiết bị xác nhận`, disable duplicate action |
| `active/correct` | Primary/positive tone, voice cadence bình thường |
| `warning` | Warning banner + icon + câu hành động cụ thể, rung nhẹ theo preference |
| `connection_lost` | Banner `Mất kết nối với ứng dụng`; nói rõ thiết bị vẫn tự bảo vệ; thử reconnect |
| `paused` | Scrim nhẹ, timer pause, `Tiếp tục` chỉ khi check passed |
| `critical/aborted` | Full-screen alert, `Thiết bị đã dừng hỗ trợ`, hướng dẫn ngồi/nằm an toàn và gọi liên hệ |

Không có nút dismiss critical để quay lại active. Reset cần thao tác vật lý/pre-flight mới.

### D. Kết quả và tiến độ

| ID | Màn hình | Nội dung |
|---|---|---|
| `RS-01` | Kết quả buổi tập | Hoàn thành/đã dừng; thời gian; reps; tỷ lệ đúng; ROM; cảnh báo; 1–3 nhận xét dễ hiểu |
| `PR-01` | Tổng quan tiến độ | Filter tuần/tháng; planned/completed; thời gian; tỷ lệ đúng; xu hướng |
| `PR-02` | Lịch sử | List theo ngày, exercise, status; filter |
| `PR-03` | Chi tiết session | Summary, chart góc có chú thích, timeline cảnh báo, data quality |

Không dùng câu gây áp lực khi session aborted. Copy mẫu: `Buổi tập đã dừng để bảo đảm an toàn.`

Chart:

- Có title, unit, legend và textual summary.
- Không dùng màu đơn độc để phân biệt; thêm line style/marker.
- Cho phép bật/tắt lưng/hông/gối, không hiển thị quá 3–4 series cùng lúc.
- Missing data là gap, không nối thành đường giả.

### E. Device

| ID | Màn hình | Nội dung/Hành động |
|---|---|---|
| `DV-01` | Thiết bị | Online, pin, firmware, calibration, sensor/motor status, lần cuối kết nối |
| `DV-02` | Ghép thiết bị | Scan QR hoặc nhập serial/code; xác nhận đúng patient |
| `DV-03` | Calibration | Stepper, sensor feedback, kết quả/version/expiry |
| `DV-04` | Chẩn đoán | Checklist read-only, export support code; không có raw motor control |
| `DV-05` | Cấu hình | Âm thanh, rung, assistance level trong phạm vi được plan cho phép |

Unpair yêu cầu xác nhận và giải thích session đang active sẽ không được phép unpair.

### F. Caregiver/clinician

| ID | Màn hình | Nội dung |
|---|---|---|
| `CA-01` | Danh sách người tập | Search, trạng thái hôm nay, alert badge; chỉ patient được cấp quyền |
| `CA-02` | Tổng quan patient | Plan, adherence, last session, trend, device health, alert |
| `CA-03` | Chi tiết alert | Severity, time, local action, session snapshot, acknowledge |
| `CL-01` | Plan editor | Chọn exercise version, schedule, target, approved assistance/limit profile |
| `CL-02` | Review session | Summary, quality flag, assessment explanation, note |

Plan editor dùng stepper/structured fields, không cho nhập JSON hay raw motor values. Publish hiển thị diff và yêu cầu xác nhận.

### G. Profile, privacy và hỗ trợ

`PF-01` hồ sơ; `PF-02` mạng lưới chăm sóc; `PF-03` notification preferences; `PF-04` accessibility; `PF-05` consent/privacy/export/delete; `PF-06` help/contact/emergency instructions; `PF-07` app/device version.

## 5. Component mapping

| Nhu cầu | Material 3 component |
|---|---|
| Primary navigation | `NavigationBar` |
| Section switch trong progress | `SegmentedButton` hoặc tabs |
| Exercise/status item | `Card`/`ListTile` |
| Lọc history | `FilterChip` + modal bottom sheet |
| Primary action | `FilledButton` |
| Secondary action | `FilledButton.tonal` / `OutlinedButton` |
| Warning inline | `MaterialBanner` custom semantics |
| Confirm destructive | `AlertDialog`; critical stop không dùng swipe |
| Loading skeleton | Placeholder giữ layout; spinner cho action ngắn |
| Empty/error | Icon/illustration nhỏ + title + action retry |
| Form | `TextFormField`, label luôn rõ, supporting/error text |

## 6. Trạng thái chuẩn cho mọi page

Mỗi feature phải thiết kế đủ:

- `initial/loading`
- `content`
- `empty`
- `recoverable_error` với retry
- `unauthorized/revoked`
- `offline_stale` có last-updated time
- `submitting` chống double action

Không dùng full-page loading khi refresh dữ liệu đã có; giữ stale content và báo updating.

## 7. Kiến trúc Flutter đề xuất

Giữ BLoC, AutoRoute, Dio/Retrofit và DI hiện có nhưng tổ chức theo feature:

```text
lib/
├─ app/                 # bootstrap, router, theme, localization
├─ core/                # result/error, network, storage, common widgets
└─ features/
   ├─ auth/
   │  ├─ data/
   │  ├─ domain/
   │  └─ presentation/
   ├─ devices/
   ├─ exercises/
   ├─ sessions/
   ├─ progress/
   ├─ care/
   └─ profile/
```

- BLoC state là immutable UI state; không để widget tự gọi repository.
- Repository map API DTO sang domain model; DTO không đi thẳng vào UI.
- Realtime gateway merge event theo resource version và refetch REST khi gap/reconnect.
- Token trong secure storage; non-sensitive cache có schema version/migration.
- Generated files vẫn generate, không chỉnh tay.

## 8. Analytics không nhạy cảm

Event mẫu: `onboarding_completed`, `device_pairing_completed`, `preflight_failed(reason_code)`, `session_start_requested`, `session_completed`, `session_aborted(reason_code)`. Không gửi raw telemetry, email, tên, free-text clinical note hoặc token vào product analytics.

