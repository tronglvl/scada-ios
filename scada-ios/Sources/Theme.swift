import SwiftUI

/// Bảng màu lấy đúng từ bản Android để hai nền tảng nhìn giống nhau.
enum Theme {
    static let navy = Color(red: 0.145, green: 0.208, blue: 0.525)   // #253586
    static let blue = Color(red: 0.082, green: 0.604, blue: 0.773)   // #159AC5
    static let green = Color(red: 0.118, green: 0.620, blue: 0.388)  // #1E9E63
    static let background = Color(red: 0.945, green: 0.980, blue: 0.988) // #F1FAFC
    static let ink = Color(red: 0.086, green: 0.196, blue: 0.290)    // #16324A
    static let muted = Color(red: 0.467, green: 0.565, blue: 0.635)  // #7790A2
    static let danger = Color(red: 0.851, green: 0.290, blue: 0.290) // #D94A4A
    static let softLine = Color(red: 0.902, green: 0.933, blue: 0.949) // #E6EEF2
    static let mint = Color(red: 0.604, green: 0.902, blue: 0.741)   // #9AE6BD
    static let sky = Color(red: 0.749, green: 0.851, blue: 1.0)      // #BFD9FF
}

extension Double {
    /// Chỉ số đồng hồ: số nguyên m³, không phân cách hàng nghìn — đọc liền một
    /// dãy đúng như dãy số trên mặt đồng hồ nước.
    var meterReading: String { String(Int(self.rounded())) }

    func fixed(_ digits: Int) -> String { String(format: "%.\(digits)f", self) }
}
