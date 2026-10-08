# 09. Material 3 design system — Blue

## 1. Brand direction

Cảm giác cần đạt: tin cậy, bình tĩnh, rõ ràng, không mang vẻ “máy móc nguy hiểm”. Xanh dương là màu thương hiệu và hành động chính; màu semantic vẫn giữ xanh lá/vàng/đỏ để người dùng nhận biết trạng thái, luôn đi kèm icon và text.

Seed color đề xuất: **`#0061A4`**. Khi triển khai Flutter, dùng `ColorScheme.fromSeed(seedColor: ...)` làm nền và override các token đã duyệt để light/dark ổn định giữa phiên bản framework.

## 2. Color tokens

### Light scheme

| Token | Hex | Dùng cho |
|---|---|---|
| `primary` | `#0061A4` | Primary button, active navigation, link |
| `onPrimary` | `#FFFFFF` | Nội dung trên primary |
| `primaryContainer` | `#D1E4FF` | Tonal card/chip, selected state |
| `onPrimaryContainer` | `#001D36` | Nội dung trên primary container |
| `secondary` | `#526070` | Hành động phụ |
| `onSecondary` | `#FFFFFF` | Nội dung trên secondary |
| `secondaryContainer` | `#D5E4F7` | Secondary tonal surface |
| `onSecondaryContainer` | `#0E1D2A` | Nội dung secondary container |
| `tertiary` | `#4A627B` | Dữ liệu phụ/chart series |
| `surface` | `#F8F9FF` | Background chính |
| `surfaceContainerLow` | `#F2F3FA` | Section/card nhẹ |
| `surfaceContainer` | `#ECEEF5` | Card/input nền |
| `surfaceContainerHigh` | `#E6E8EF` | Modal/selected neutral |
| `onSurface` | `#191C20` | Text chính |
| `onSurfaceVariant` | `#42474E` | Text phụ |
| `outline` | `#73777F` | Border đủ tương phản |
| `outlineVariant` | `#C3C7CF` | Divider nhẹ |
| `error` | `#BA1A1A` | Error/critical |
| `onError` | `#FFFFFF` | Nội dung trên error |
| `errorContainer` | `#FFDAD6` | Error surface |
| `onErrorContainer` | `#410002` | Nội dung error surface |

### Dark scheme

| Token | Hex |
|---|---|
| `primary` | `#9ECAFF` |
| `onPrimary` | `#003258` |
| `primaryContainer` | `#00497D` |
| `onPrimaryContainer` | `#D1E4FF` |
| `secondary` | `#B9C8DA` |
| `onSecondary` | `#243240` |
| `secondaryContainer` | `#3A4857` |
| `onSecondaryContainer` | `#D5E4F7` |
| `surface` | `#111418` |
| `surfaceContainer` | `#1D2024` |
| `surfaceContainerHigh` | `#282A2F` |
| `onSurface` | `#E2E2E8` |
| `onSurfaceVariant` | `#C3C7CF` |
| `outline` | `#8D9199` |
| `error` | `#FFB4AB` |
| `errorContainer` | `#93000A` |

Dark mode là tính năng sau khi light mode đạt accessibility, nhưng token phải sẵn để không hard-code màu trong widget.

### Semantic status

| Trạng thái | Foreground | Container | Icon/text bắt buộc |
|---|---|---|---|
| Success/ready | `#146C2E` | `#C4EED0` | `check_circle`, `Sẵn sàng/Hoàn thành` |
| Warning | `#765A00` | `#FFE08A` | `warning_amber`, chỉ dẫn cụ thể |
| Critical/error | `#BA1A1A` | `#FFDAD6` | `error`, nguyên nhân + hành động |
| Info | `#0061A4` | `#D1E4FF` | `info`, thông tin |
| Offline/unknown | `#5E5E65` | `#E5E1E6` | `cloud_off/help`, last updated |

Các màu status không thay thế M3 `ColorScheme`; định nghĩa bằng `ThemeExtension<StatusColors>`.

## 3. Typography

Font: `Roboto` trên Android/Flutter mặc định; nếu bundle font, bảo đảm đầy đủ Vietnamese glyph và license. Không dùng font trang trí cho nội dung sức khỏe.

| Style | Size/line | Weight | Dùng cho |
|---|---:|---:|---|
| `displaySmall` | 36/44 | 600 | Số reps/timer live |
| `headlineMedium` | 28/36 | 600 | Tiêu đề kết quả |
| `headlineSmall` | 24/32 | 600 | Tiêu đề page |
| `titleLarge` | 22/28 | 600 | App bar/card hero |
| `titleMedium` | 16/24 | 600 | Card/list title |
| `bodyLarge` | 18/28 | 400 | Nội dung mặc định cho patient |
| `bodyMedium` | 16/24 | 400 | Nội dung phụ |
| `labelLarge` | 16/24 | 600 | Button |
| `labelMedium` | 14/20 | 600 | Chip/status |

Patient mode ưu tiên `bodyLarge` 18 sp thay vì M3 default nhỏ hơn. Hỗ trợ text scale ít nhất 200%; layout không dùng fixed height chứa text dài.

## 4. Spacing, size và shape

- Grid cơ sở: 4 dp.
- Page horizontal padding: 16 dp phone, 24 dp tablet.
- Khoảng section: 24–32 dp; card internal: 16–20 dp.
- Touch target tối thiểu: 48×48 dp; primary patient action cao khuyến nghị 56 dp.
- Icon thường 24 dp; status hero 40–48 dp.
- Radius: small 8 dp, medium 12 dp, large 16 dp, extra-large 28 dp, full pill.
- Không dùng stadium/pill cho mọi input/card; dùng shape theo M3 và giữ hierarchy.

## 5. Elevation và surface

Ưu tiên tonal surface/outline hơn shadow mạnh:

- Level 0: page background.
- Level 1: card thường/navigation bar.
- Level 2: floating controls/sticky action.
- Level 3: modal bottom sheet/dialog.

M3 surface tint theo color scheme; không hard-code shadow đen. Critical banner dùng container semantic, không tăng elevation để biểu thị severity.

## 6. Component specifications

### Buttons

- `FilledButton`: một primary action/page (`Bắt đầu`, `Lưu`, `Tiếp tục`).
- `FilledButton.tonal`: secondary safe action (`Hiệu chỉnh`, `Xem chi tiết`).
- `OutlinedButton`: alternative/back.
- `TextButton`: low priority.
- Destructive: foreground error, confirm dialog; không dùng primary blue.
- Loading giữ nguyên width, disable và có label semantics `Đang xử lý`.

### Cards

- Exercise card: leading illustration/icon, title, target/duration, status chip, chevron/action.
- Device status card: icon + explicit text + last seen; toàn card chỉ clickable khi semantics rõ.
- Metric card: label, value, unit, trend; không viết `80` mà thiếu `%/độ/phút`.

### Inputs

- M3 filled hoặc outlined field; label không biến mất khi có giá trị.
- Radius 12 dp, content padding cho touch target; prefix/suffix icon có tooltip.
- Error text nói cách sửa, ví dụ `Mật khẩu cần ít nhất 8 ký tự`.
- Numeric clinical fields có unit suffix và min/max từ schema; vẫn validate server.

### Navigation

- `NavigationBar` M3, indicator `primaryContainer`, selected icon/text `onPrimaryContainer`.
- App bar không center mọi title theo iOS cũ; theo platform/M3 và nhất quán.
- Trong live session ẩn bottom bar để tránh bấm nhầm.

### Alerts

- Info/warning inline dùng banner/card với icon + title + description + action.
- Critical active dùng full-screen blocking surface; focus/semantics chuyển vào alert.
- Snackbar chỉ cho feedback không critical như `Đã lưu`; không dùng cho e-stop/overcurrent.

## 7. Motion và haptics

- Transition 200–300 ms, easing Material; tôn trọng reduce motion.
- Không animate liên tục biểu đồ/tư thế gây phân tâm; live metric dùng update ổn định, tránh nhảy layout.
- Warning: haptic nhẹ có kiểm soát; critical pattern riêng nhưng không thay thế âm thanh/phần cứng.
- Không dùng animation ăn mừng khi người dùng có cảnh báo đau/mệt hoặc session vừa aborted.

## 8. Accessibility checklist

- Text/background đạt WCAG AA; kiểm tra token bằng công cụ, không phán đoán mắt.
- Mọi icon-only button có semantic label/tooltip.
- Focus order đúng; screen reader đọc status thay đổi có throttle, không đọc 5 lần/giây.
- Màu chart có marker/line style và summary text.
- Form error liên kết với field; dialog không làm mất focus.
- Hỗ trợ TalkBack/VoiceOver, landscape hợp lý và tablet.
- Copy tránh thuật ngữ kỹ thuật: dùng `Thiết bị chưa sẵn sàng` thay `IMU timeout`, đặt mã kỹ thuật trong chi tiết hỗ trợ.
- Test với người cao tuổi/thị lực kém và run usability pilot, không chỉ automated contrast test.

## 9. Flutter theme migration

Code hiện tại đang `useMaterial3: false`, `primarySwatch` và nhiều control dạng `StadiumBorder`. Hướng chuyển:

1. Đặt `useMaterial3: true`; bỏ phụ thuộc `primarySwatch` cho token chính.
2. Tạo light/dark `ColorScheme` từ seed và token ở mục 2.
3. Tạo `StatusColors extends ThemeExtension`.
4. Chuẩn hóa `TextTheme`, button/input/card/navigation theme.
5. Không gọi hex trực tiếp trong feature widget; chỉ dùng `Theme.of(context).colorScheme` hoặc extension.
6. Golden test các component/state và accessibility test trước khi thay toàn bộ page.

Skeleton:

```dart
const seedBlue = Color(0xFF0061A4);

final colorScheme = ColorScheme.fromSeed(
  seedColor: seedBlue,
  brightness: Brightness.light,
).copyWith(
  primary: const Color(0xFF0061A4),
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFD1E4FF),
  onPrimaryContainer: const Color(0xFF001D36),
  surface: const Color(0xFFF8F9FF),
  error: const Color(0xFFBA1A1A),
);

final theme = ThemeData(
  useMaterial3: true,
  colorScheme: colorScheme,
  scaffoldBackgroundColor: colorScheme.surface,
  visualDensity: VisualDensity.standard,
);
```

Đoạn trên là nền, chưa thay thế component theme/accessibility được mô tả trong tài liệu.

## 10. Copy mẫu tiếng Việt

| Trường hợp | Copy |
|---|---|
| Ready | `Thiết bị đã sẵn sàng.` |
| Calibration | `Đứng thẳng và giữ yên trong 5 giây.` |
| Posture warning | `Giữ lưng thẳng hơn một chút.` |
| Tempo warning | `Hãy thực hiện chậm lại.` |
| Connection lost | `Ứng dụng mất kết nối. Thiết bị vẫn đang tự bảo vệ bạn.` |
| Critical stop | `Thiết bị đã dừng hỗ trợ để bảo đảm an toàn.` |
| Missing data | `Chưa đủ dữ liệu để đánh giá mục này.` |
| AI uncertain | `Hệ thống chưa thể đánh giá chắc chắn động tác này.` |

Không dùng `Bạn tập sai` hoặc ngôn ngữ đổ lỗi; nói về động tác và hướng sửa.

