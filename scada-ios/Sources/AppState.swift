import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var session: TeamSession?
    @Published var devices: [DeviceSummary] = []
    @Published var readings: [String: DeviceReadings] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let sessionKey = "scada.session"

    init() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let saved = try? JSONDecoder().decode(TeamSession.self, from: data) {
            session = saved
        }
    }

    // MARK: - Đăng nhập bằng mã đội

    func login(code: String) async -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Vui lòng nhập mã đội." }
        do {
            let result = try await ApiClient.shared.checkTeam(code: trimmed)
            session = result
            if let data = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(data, forKey: sessionKey)
            }
            await refresh()
            return nil
        } catch {
            return friendly(error)
        }
    }

    func logout() {
        session = nil
        devices = []
        readings = [:]
        lastUpdated = nil
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    // MARK: - Tải dữ liệu

    func refresh() async {
        guard let session else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let list = try await ApiClient.shared.devices(companyId: session.idcty,
                                                          teamCode: session.teamCode)
            devices = list
            errorMessage = list.isEmpty ? "Chưa có thiết bị nào trong đội này." : nil

            // Tải song song để danh sách dài không phải chờ tuần tự từng thiết bị.
            await withTaskGroup(of: (String, DeviceReadings?).self) { group in
                for device in list {
                    group.addTask {
                        let data = try? await ApiClient.shared.readings(deviceId: device.iddevice)
                        return (device.iddevice, data)
                    }
                }
                for await (id, data) in group {
                    if let data { readings[id] = data }
                }
            }
            lastUpdated = Date()
        } catch {
            // Giữ nguyên dữ liệu cũ trên màn hình khi mất mạng, chỉ báo lỗi.
            errorMessage = friendly(error)
        }
    }

    func readings(for device: DeviceSummary) -> DeviceReadings {
        readings[device.iddevice] ?? DeviceReadings()
    }

    private func friendly(_ error: Error) -> String {
        if let api = error as? ApiError { return api.localizedDescription }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet: return "Thiết bị đang không có mạng."
            case NSURLErrorTimedOut: return "Máy chủ phản hồi quá chậm."
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                return "Không kết nối được tới máy chủ \(Config.baseURL)."
            default: break
            }
        }
        return "Không thể kết nối máy chủ: \(ns.localizedDescription)"
    }
}
