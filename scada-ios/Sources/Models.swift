import Foundation

// Các model bám đúng JSON của bộ API /android/api/ trên máy chủ SCADA.
//
// Vì sao tự viết init(from:) thay vì để Swift sinh tự động:
//
// 1. Bộ giải mã do Swift sinh KHÔNG dùng giá trị mặc định của thuộc tính khi
//    JSON thiếu key — nó ném keyNotFound và làm hỏng cả mảng. Máy chủ lại có
//    nhiều trường tuỳ chọn (địa chỉ trống, chưa có cảm biến, chưa có chỉ số
//    tổng), nên một thiết bị thiếu trường sẽ kéo sập cả danh sách.
// 2. JSON trộn nhiều kiểu đặt tên (`iddevice`, `ten_nha_may`, `sensorType`) và
//    một số phiên bản máy chủ trả PascalCase. Đọc thủ công cho phép thử lần
//    lượt nhiều tên khoá, đúng như bản Android vẫn làm với optString().
//
// Thời gian giữ nguyên dạng chuỗi: máy chủ trả ISO không kèm múi giờ và có tới
// 7 chữ số phần giây (2026-09-10T16:56:38.7986995) — dạng này làm chiến lược
// .iso8601 thất bại. Việc chuyển sang Date do DateParsing lo, phân tích không
// được thì chỉ mất phần hiển thị giờ chứ không mất số liệu đo.

/// Đọc giá trị theo nhiều tên khoá có thể có, trả nil nếu không khoá nào tồn tại.
private struct FlexibleKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }   // khoá số không dùng tới
    init(_ s: String) { self.stringValue = s }
}

private extension KeyedDecodingContainer where Key == FlexibleKey {
    func str(_ names: String..., default def: String = "") -> String {
        for n in names {
            if let k = FlexibleKey(stringValue: n), let v = try? decodeIfPresent(String.self, forKey: k), let v {
                return v
            }
        }
        return def
    }
    func dbl(_ names: String...) -> Double? {
        for n in names {
            guard let k = FlexibleKey(stringValue: n) else { continue }
            if let v = try? decodeIfPresent(Double.self, forKey: k), let v { return v }
            // Vài trường số có thể về dạng chuỗi tuỳ cấu hình serializer.
            if let s = try? decodeIfPresent(String.self, forKey: k), let s, let v = Double(s) { return v }
        }
        return nil
    }
    func int(_ names: String...) -> Int? {
        for n in names {
            guard let k = FlexibleKey(stringValue: n) else { continue }
            if let v = try? decodeIfPresent(Int.self, forKey: k), let v { return v }
        }
        return nil
    }
    func list<T: Decodable>(_ names: String..., of type: T.Type) -> [T] {
        for n in names {
            guard let k = FlexibleKey(stringValue: n) else { continue }
            if let v = try? decodeIfPresent([T].self, forKey: k), let v { return v }
        }
        return []
    }
}

// MARK: - Phiên đăng nhập

struct TeamSession: Codable, Equatable {
    var idcty: Int = 0
    var teamName: String = ""
    var teamCode: String = ""

    init(idcty: Int, teamName: String, teamCode: String) {
        self.idcty = idcty; self.teamName = teamName; self.teamCode = teamCode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FlexibleKey.self)
        idcty = c.int("idcty", "IdCty") ?? 0
        teamName = c.str("teamName", "TeamName")
        teamCode = c.str("teamCode", "TeamCode")
    }
}

// MARK: - Cấu hình cảm biến

struct SensorDefinition: Codable, Identifiable, Hashable {
    var sensorId: String = ""
    var payloadKey: String = ""
    var sensorType: String = ""
    var port: String = ""
    var unit: String = ""
    var maxCapacity: Double = 0

    var id: String { sensorId.isEmpty ? "\(sensorType)-\(port)" : sensorId }
    var isPressure: Bool { SensorKind.isPressure(sensorType) }
    var isFlow: Bool { SensorKind.isFlow(sensorType) }

    /// Đơn vị hiển thị, tự suy ra khi máy chủ để trống.
    var displayUnit: String {
        if !unit.isEmpty { return unit }
        if isPressure { return "kg/cm²" }
        if isFlow { return "m³/h" }
        return ""
    }

    init(sensorType: String = "", port: String = "", unit: String = "") {
        self.sensorType = sensorType; self.port = port; self.unit = unit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FlexibleKey.self)
        sensorId = c.str("sensorId", "SensorId")
        payloadKey = c.str("payloadKey", "PayloadKey")
        sensorType = c.str("sensorType", "SensorType", "type", default: "Cảm biến")
        port = c.str("port", "Port")
        unit = c.str("unit", "Unit", "originalUnit", "OriginalUnit")
        maxCapacity = c.dbl("maxCapacity", "MaxCapacity") ?? 0
    }
}

// MARK: - Thiết bị

struct DeviceSummary: Codable, Identifiable, Hashable {
    var iddevice: String = ""
    var tenNhaMay: String = ""
    var diaChi: String = ""
    var mat: String = ""
    var trangthai: Int = 1
    var sensors: [SensorDefinition] = []
    var totalMeter: Double?

    var id: String { iddevice }
    var hasFlowSensor: Bool { sensors.isEmpty || sensors.contains { $0.isFlow } }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FlexibleKey.self)
        iddevice = c.str("iddevice", "IdDevice", "idDevice")
        tenNhaMay = c.str("ten_nha_may", "tenNhaMay", "ten", default: "Không tên")
        diaChi = c.str("dia_chi", "diaChi", "diachi")
        mat = c.str("mat", "Mat")
        trangthai = c.int("trangthai", "TrangThai") ?? 1
        sensors = c.list("sensors", "Sensors", of: SensorDefinition.self)
        totalMeter = c.dbl("total_meter", "totalMeter")
    }
}

// MARK: - Số liệu đo

struct MeasurementRecord: Codable {
    var measuredAt: String = ""
    var pressure: Double = 0
    var flow: Double?
    var totalMeter: Double?
    var unit: String = ""
    var trangthai: Int?

    var date: Date? { DateParsing.parse(measuredAt) }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FlexibleKey.self)
        measuredAt = c.str("measured_at", "measuredAt")
        pressure = c.dbl("pressure", "Pressure") ?? 0
        flow = c.dbl("flow", "Flow")
        totalMeter = c.dbl("total_meter", "totalMeter")
        unit = c.str("unit", "Unit", default: "kg/cm²")
        trangthai = c.int("trangthai", "TrangThai")
    }
}

// MARK: - Bản đồ

struct MapDevice: Codable, Identifiable {
    var id: String = ""
    var ten: String = ""
    var diachi: String = ""
    var vido: Double = 0
    var kinhdo: Double = 0
    var latestPressure: Double = 0
    var latestFlow: Double = 0
    var totalMeter: Double?
    var trangthai: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FlexibleKey.self)
        id = c.str("id", "iddevice", "IdDevice")
        ten = c.str("ten", "ten_nha_may", default: "Không tên")
        diachi = c.str("diachi", "dia_chi")
        vido = c.dbl("vido", "latitude") ?? 0
        kinhdo = c.dbl("kinhdo", "longitude") ?? 0
        latestPressure = c.dbl("latest_pressure", "latestPressure") ?? 0
        latestFlow = c.dbl("latest_flow", "latestFlow") ?? 0
        totalMeter = c.dbl("total_meter", "totalMeter")
        trangthai = c.int("trangthai", "TrangThai")
    }
}

// MARK: - Tổng hợp cho giao diện

/// Dữ liệu đã gom cho một thiết bị, dùng chung cho tab Áp lực và Lưu lượng.
struct DeviceReadings {
    var records: [MeasurementRecord] = []
    var totalMeter: Double?

    var pressureSeries: [Double] { records.map(\.pressure) }
    var flowSeries: [Double] { records.compactMap(\.flow) }
    var latestPressure: Double? { records.last?.pressure }
    var latestFlow: Double? { flowSeries.last }
    var latestTime: Date? { records.last?.date }
    var hasFlowData: Bool { !flowSeries.isEmpty || totalMeter != nil }
}

enum SensorKind {
    static func isPressure(_ type: String) -> Bool {
        let t = type.lowercased()
        return t.contains("pressure") || t.contains("áp lực")
    }
    static func isFlow(_ type: String) -> Bool {
        let t = type.lowercased()
        return t.contains("flow") || t.contains("lưu lượng")
    }
}

enum DateParsing {
    /// Máy chủ trả nhiều biến thể: có/không phần giây lẻ, có/không múi giờ.
    /// Thử lần lượt thay vì phụ thuộc một bộ giải mã duy nhất.
    private static let formatters: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
         "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
         "yyyy-MM-dd'T'HH:mm:ss.SSS",
         "yyyy-MM-dd'T'HH:mm:ss",
         "yyyy-MM-dd HH:mm:ss"].map { pattern in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = pattern
            return f
        }
    }()

    static func parse(_ raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }
        for f in formatters {
            if let date = f.date(from: raw) { return date }
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    static let display: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "HH:mm dd/MM"
        return f
    }()

    static let apiDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
