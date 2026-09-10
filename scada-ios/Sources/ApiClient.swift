import Foundation

enum ApiError: LocalizedError {
    case badURL
    case http(Int)
    case empty
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Địa chỉ máy chủ không hợp lệ."
        case .http(let code): return "Máy chủ trả về lỗi \(code)."
        case .empty: return "Máy chủ không trả về dữ liệu."
        case .decoding(let detail): return "Dữ liệu trả về không đọc được: \(detail)"
        }
    }
}

/// Lớp gọi API. Toàn bộ endpoint của app đều là POST JSON dưới /android/api/,
/// giống hệt bản Android nên máy chủ không phải thêm gì.
actor ApiClient {
    static let shared = ApiClient()

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 30
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Không dùng convertFromSnakeCase: JSON trộn cả hai kiểu (`iddevice`,
        // `ten_nha_may`, `sensorType`), nên các model tự khai CodingKeys.
        return d
    }()

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: Config.baseURL + path) else { throw ApiError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ApiError.http(http.statusCode)
        }
        if data.isEmpty { throw ApiError.empty }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ApiError.decoding(String(describing: error))
        }
    }

    // MARK: - Endpoint

    func checkTeam(code: String) async throws -> TeamSession {
        try await post("/android/api/auth/check-team", body: ["CodeTeam": code])
    }

    /// Danh sách thiết bị của công ty, lọc theo mã đội ở phía client — giống
    /// đúng cách bản Android làm (máy chủ không có bộ lọc theo đội cho API này).
    func devices(companyId: Int, teamCode: String) async throws -> [DeviceSummary] {
        let all: [DeviceSummary] = try await post("/android/api/by-company", body: ["IdCty": companyId])
        let filter = teamCode.trimmingCharacters(in: .whitespaces)
        guard !filter.isEmpty else { return all }
        return all.filter { $0.mat.caseInsensitiveCompare(filter) == .orderedSame }
    }

    func readings(deviceId: String) async throws -> DeviceReadings {
        let rows: [MeasurementRecord] = try await post("/android/api/latest-pressure",
                                                       body: ["IdDevice": deviceId])
        // Chỉ số tổng là trạng thái hiện tại nên mọi bản ghi mang cùng giá trị;
        // lấy giá trị cuối cùng khác nil.
        let total = rows.compactMap(\.totalMeter).last
        return DeviceReadings(records: rows, totalMeter: total)
    }

    func mapDevices(companyId: Int, teamCode: String) async throws -> [MapDevice] {
        try await post("/android/api/map-by-team",
                       body: ["IdCty": companyId, "TeamCode": teamCode])
    }

    func history(deviceId: String, from: Date, to: Date) async throws -> [MeasurementRecord] {
        try await post("/android/api/history-pressure", body: [
            "IdDevice": deviceId,
            "FromDate": DateParsing.apiDay.string(from: from),
            "ToDate": DateParsing.apiDay.string(from: to)
        ])
    }
}
