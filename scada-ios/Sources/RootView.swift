import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if app.session == nil {
            LoginView()
        } else {
            MainTabs()
        }
    }
}

private struct MainTabs: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $tab) {
                PressureView()
                    .tabItem { Label("Áp lực", systemImage: "chart.xyaxis.line") }.tag(0)
                FlowView()
                    .tabItem { Label("Lưu lượng", systemImage: "drop.fill") }.tag(1)
                MapScreen()
                    .tabItem { Label("Bản đồ", systemImage: "map.fill") }.tag(2)
                HistoryView()
                    .tabItem { Label("Lịch sử", systemImage: "list.bullet.rectangle") }.tag(3)
            }
            .tint(Theme.navy)
            .navigationTitle(titleForTab)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(titleForTab).font(.system(size: 14, weight: .bold))
                        if let s = app.session {
                            Text("Đội \(s.teamCode)").font(.system(size: 10)).foregroundStyle(Theme.sky)
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if app.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Button { Task { await app.refresh() } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    Menu {
                        if let t = app.lastUpdated {
                            Text("Cập nhật \(DateParsing.display.string(from: t))")
                        }
                        Button(role: .destructive) { app.logout() } label: {
                            Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .toolbarBackground(Theme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            // Tự làm mới định kỳ. Vòng lặp gắn với vòng đời của view nên khi
            // đóng màn hình là dừng, không rò rỉ Task chạy nền.
            if app.devices.isEmpty { await app.refresh() }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Config.refreshInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await app.refresh()
            }
        }
        .onChange(of: scenePhase) { phase in
            // Quay lại từ nền: số liệu đã cũ, nạp lại ngay thay vì chờ hết chu kỳ.
            if phase == .active { Task { await app.refresh() } }
        }
    }

    private var titleForTab: String {
        switch tab {
        case 0: return "ÁP LỰC NƯỚC"
        case 1: return "LƯU LƯỢNG & ĐỒNG HỒ"
        case 2: return "BẢN ĐỒ TRẠM"
        default: return "LỊCH SỬ"
        }
    }
}
