import SwiftUI

@main
struct ScadaApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(Theme.navy)
                // Toàn bộ nội dung là tiếng Việt và các bảng số liệu đọc rõ hơn
                // ở nền sáng, nên khoá giao diện sáng thay vì theo hệ thống.
                .preferredColorScheme(.light)
        }
    }
}
