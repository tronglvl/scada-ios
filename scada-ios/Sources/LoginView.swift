import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var app: AppState
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.navy, Theme.blue],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer().frame(height: 60)

                    Image(systemName: "drop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)

                    VStack(spacing: 5) {
                        Text("GIÁM SÁT CẤP NƯỚC")
                            .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                        Text("Áp lực · Lưu lượng · Đồng hồ tổng")
                            .font(.system(size: 12)).foregroundStyle(Theme.sky)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mã đội").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)

                        TextField("Nhập mã đội của bạn", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .submitLabel(.go)
                            .onSubmit { Task { await submit() } }
                            .padding(12)
                            .background(Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        if let error {
                            Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.white) }
                                Text(busy ? "Đang kiểm tra..." : "Đăng nhập")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(busy ? Theme.muted : Theme.navy)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                        .disabled(busy)
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 22)

                    Text("Máy chủ: \(Config.baseURL)")
                        .font(.system(size: 10)).foregroundStyle(Theme.sky.opacity(0.8))
                    Spacer()
                }
            }
        }
        .onAppear { focused = true }
    }

    private func submit() async {
        guard !busy else { return }
        busy = true
        error = await app.login(code: code)
        busy = false
    }
}
