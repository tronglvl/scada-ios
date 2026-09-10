# SCADA iOS — Giám sát cấp nước

Bản iOS (SwiftUI) của ứng dụng giám sát SCADA, làm tương đương bản Android
`bandung2`. Dùng đúng bộ API `/android/api/` có sẵn trên máy chủ — **không cần
thay đổi gì phía server**.

## Yêu cầu bắt buộc

| | |
|---|---|
| **macOS + Xcode 15 trở lên** | Bắt buộc. Trình biên dịch Swift cho iOS, iOS SDK và `xcodebuild` chỉ Apple phát hành cho macOS. Không có cách build IPA trên Windows hay Linux. |
| **XcodeGen** | `brew install xcodegen`. Script build tự cài nếu thiếu. |
| Tài khoản Apple Developer | **Không bắt buộc** để build (bản dựng ra không ký). Chỉ cần khi muốn ký chính thức / đưa lên TestFlight. |

## Build

```bash
chmod +x build-ipa.sh
./build-ipa.sh
```

Kết quả: `SCADA-unsigned.ipa` ở thư mục gốc.

Không có máy Mac? Đẩy repo lên GitHub rồi vào tab **Actions → Build IPA
(unsigned) → Run workflow**. Workflow chạy trên máy ảo macOS của GitHub và cho
tải file IPA ở mục Artifacts.

## Cài lên iPhone

File dựng ra **chưa được ký**, iOS không cho cài trực tiếp. Ba cách:

1. **Sideloadly** (Windows/macOS) hoặc **AltStore** — đăng nhập Apple ID miễn
   phí, công cụ tự ký lại rồi cài. Ứng dụng chạy được **7 ngày**, hết hạn thì mở
   công cụ ký lại. Đủ dùng cho nội bộ, không tốn phí.
2. **Tài khoản Apple Developer** (99 USD/năm) — ký bằng certificate riêng, app
   dùng được 1 năm, phát hành nội bộ qua TestFlight.
3. **Xcode** — cắm iPhone vào máy Mac, mở `Scada.xcodeproj`, chọn Team trong
   *Signing & Capabilities* rồi bấm Run.

## Đổi địa chỉ máy chủ

Sửa `Sources/Config.swift`:

```swift
static let baseURL = "http://113.164.79.165:5000"
```

Máy chủ đang chạy **HTTP thuần**, nên `project.yml` đã khai báo ngoại lệ
`NSAppTransportSecurity` — thiếu khai báo này iOS chặn hết mọi lời gọi API.
Khi nào máy chủ chuyển sang HTTPS thì nên bỏ ngoại lệ đó đi.

## Cấu trúc

```
Sources/
  ScadaApp.swift      điểm khởi động
  Config.swift        địa chỉ máy chủ, chu kỳ làm mới
  Theme.swift         bảng màu (lấy từ bản Android)
  Models.swift        model khớp JSON của API
  ApiClient.swift     gọi API (async/await)
  AppState.swift      phiên đăng nhập + tải dữ liệu
  RootView.swift      thanh tab + tự làm mới 30 giây
  LoginView.swift     đăng nhập bằng mã đội
  PressureView.swift  tab Áp lực
  FlowView.swift      tab Lưu lượng & Đồng hồ tổng
  MapScreen.swift     tab Bản đồ (MapKit)
  HistoryView.swift   tab Lịch sử theo khoảng ngày
  Components.swift    biểu đồ nhỏ, thẻ, ô KPI
Resources/
  Assets.xcassets     icon ứng dụng, màu nhấn
project.yml           đặc tả dự án cho XcodeGen
build-ipa.sh          script dựng IPA
```

## Màn hình

- **Áp lực** — mỗi thiết bị một thẻ, liệt kê từng cảm biến kèm biểu đồ. Cảm biến
  lưu lượng cũng có biểu đồ riêng và hiện chỉ số đồng hồ tổng.
- **Lưu lượng & Đồng hồ tổng** — ba ô tổng hợp (số thiết bị, tổng lưu lượng,
  tổng chỉ số), rồi từng thiết bị với lưu lượng tức thời + chỉ số đồng hồ.
- **Bản đồ** — vị trí các trạm, chạm vào điểm để xem áp lực / lưu lượng / chỉ số.
- **Lịch sử** — chọn thiết bị và khoảng ngày, xem biểu đồ áp lực + lưu lượng và
  bảng số liệu.

Chỉ số đồng hồ tổng hiển thị **số nguyên m³, không phân cách hàng nghìn**, đọc
liền một dãy đúng như dãy số trên mặt đồng hồ nước.

## Lưu ý

Phần lưu lượng và đồng hồ tổng chỉ có số khi máy chủ đã chạy bản `AndroidController`
mới (bản cũ luôn trả `flow: null`, `total_meter: null` vì đọc từ cột JSON đã bị
bỏ khỏi database). Ngoài ra cảm biến lưu lượng phải được khai báo **giá trị 1
xung** và **chỉ số ban đầu** trong DeviceCenter.
