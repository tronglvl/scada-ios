import Foundation

enum Config {
    /// Địa chỉ máy chủ SCADA. Trùng với `BASE_URL` trong bản Android (AppConfig.kt).
    /// Đây là HTTP thuần nên Info.plist phải có ngoại lệ ATS, xem project.yml.
    static let baseURL = "http://113.164.79.165:5000"

    /// Chu kỳ tự làm mới dữ liệu, khớp với bản Android (30 giây).
    static let refreshInterval: TimeInterval = 30

    /// Số mốc đo tối đa vẽ lên biểu đồ nhỏ.
    static let sparklinePoints = 50
}
