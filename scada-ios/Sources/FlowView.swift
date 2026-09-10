import SwiftUI

/// Tab Lưu lượng & Đồng hồ tổng — tính năng mới so với bản Android cũ (bản đó
/// mới chỉ dựng giao diện, hiển thị "--" vì máy chủ chưa trả dữ liệu).
struct FlowView: View {
    @EnvironmentObject private var app: AppState

    /// Chỉ giữ thiết bị có cảm biến lưu lượng. Thiết bị chưa khai báo cảm biến
    /// vẫn giữ lại vì không đủ căn cứ để loại bỏ.
    private var flowDevices: [DeviceSummary] {
        app.devices.filter(\.hasFlowSensor)
    }

    private var liveCount: Int {
        flowDevices.filter { app.readings(for: $0).hasFlowData }.count
    }

    private var totalFlow: Double {
        flowDevices.compactMap { app.readings(for: $0).latestFlow }.reduce(0, +)
    }

    private var meters: [Double] {
        flowDevices.compactMap { app.readings(for: $0).totalMeter }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HeroBanner(icon: "drop.fill",
                           title: "Theo dõi lưu lượng",
                           subtitle: "Đồng bộ cảm biến và chỉ số đồng hồ tổng",
                           badge: "\(liveCount)/\(flowDevices.count)\nCÓ DỮ LIỆU")

                HStack(spacing: 10) {
                    KpiTile(label: "THIẾT BỊ", value: "\(flowDevices.count)",
                            unit: "điểm đo", color: Theme.blue)
                    KpiTile(label: "LƯU LƯỢNG",
                            value: liveCount == 0 ? "--" : totalFlow.fixed(1),
                            unit: "m³/h", color: Theme.green)
                    KpiTile(label: "ĐỒNG HỒ TỔNG",
                            value: meters.isEmpty ? "--" : meters.reduce(0, +).meterReading,
                            unit: "m³", color: Theme.navy)
                }

                HStack {
                    Text("THIẾT BỊ VÀ CẢM BIẾN LƯU LƯỢNG")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                }

                if flowDevices.isEmpty {
                    EmptyStateBox(loading: app.isLoading,
                                  message: app.errorMessage ?? "Chưa có thiết bị lưu lượng trong đội này.")
                } else {
                    ForEach(flowDevices) { device in
                        FlowDeviceCard(device: device, readings: app.readings(for: device))
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .refreshable { await app.refresh() }
    }
}

private struct FlowDeviceCard: View {
    let device: DeviceSummary
    let readings: DeviceReadings

    var body: some View {
        CardBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    Image(systemName: "drop.fill").foregroundStyle(Theme.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.tenNhaMay.isEmpty ? device.iddevice : device.tenNhaMay)
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                        if !device.diaChi.isEmpty {
                            Text(device.diaChi).font(.system(size: 11))
                                .foregroundStyle(Theme.muted).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 6)
                    Text(readings.hasFlowData ? "LIVE" : "CHỜ DỮ LIỆU")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(readings.hasFlowData ? Theme.green : Theme.muted)
                }

                Divider().overlay(Theme.softLine)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lưu lượng hiện tại")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        Text(readings.latestFlow.map { "\($0.fixed(2)) m³/h" } ?? "-- m³/h")
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Chỉ số đồng hồ tổng")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        // Số nguyên m³, đọc liền một dãy như trên mặt đồng hồ.
                        Text(readings.totalMeter.map { "\($0.meterReading) m³" } ?? "-- m³")
                            .font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.green)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }

                Sparkline(values: readings.flowSeries, color: Theme.green, height: 56)

                if !readings.hasFlowData {
                    Text("Chưa nhận được dữ liệu lưu lượng từ thiết bị này.")
                        .font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            }
        }
    }
}
