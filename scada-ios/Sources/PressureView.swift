import SwiftUI

/// Tab Áp lực: mỗi thiết bị một thẻ, bên trong liệt kê từng cảm biến đã khai báo.
/// Cảm biến lưu lượng cũng được vẽ ở đây (bản Android cũ bỏ trống) kèm chỉ số tổng.
struct PressureView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HeroBanner(icon: "chart.xyaxis.line",
                           title: "Theo dõi áp lực nước",
                           subtitle: "Các cảm biến theo từng thiết bị",
                           badge: "\(app.devices.count)\nTHIẾT BỊ")

                if app.devices.isEmpty {
                    EmptyStateBox(loading: app.isLoading, message: app.errorMessage)
                } else {
                    ForEach(app.devices) { device in
                        DeviceSensorsCard(device: device, readings: app.readings(for: device))
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .refreshable { await app.refresh() }
    }
}

struct EmptyStateBox: View {
    let loading: Bool
    let message: String?

    var body: some View {
        CardBox {
            VStack(spacing: 10) {
                if loading {
                    ProgressView().tint(Theme.blue)
                    Text("Đang tải dữ liệu...").font(.system(size: 12)).foregroundStyle(Theme.muted)
                } else {
                    Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(Theme.muted)
                    Text(message ?? "Chưa có dữ liệu.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}

private struct DeviceSensorsCard: View {
    let device: DeviceSummary
    let readings: DeviceReadings

    /// Thiết bị đời cũ chưa khai báo cảm biến: coi như có một cảm biến áp lực AD0.
    private var definitions: [SensorDefinition] {
        device.sensors.isEmpty
            ? [SensorDefinition(sensorType: "Áp lực nước", port: "AD0", unit: "kg/cm²")]
            : device.sensors
    }

    var body: some View {
        CardBox {
            VStack(alignment: .leading, spacing: 12) {
                DeviceHeader(device: device,
                             trailing: AnyView(StatusPill(status: device.trangthai)))

                if let t = readings.latestTime {
                    Text("Cập nhật \(DateParsing.display.string(from: t))")
                        .font(.system(size: 10)).foregroundStyle(Theme.muted)
                }

                ForEach(definitions) { sensor in
                    SensorRow(sensor: sensor, readings: readings)
                    if sensor.id != definitions.last?.id {
                        Divider().overlay(Theme.softLine)
                    }
                }
            }
        }
    }
}

private struct SensorRow: View {
    let sensor: SensorDefinition
    let readings: DeviceReadings

    private var series: [Double] {
        if sensor.isPressure { return readings.pressureSeries }
        if sensor.isFlow { return readings.flowSeries }
        return []
    }

    private var current: Double? { series.last }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sensor.sensorType.isEmpty ? "Cảm biến" : sensor.sensorType)
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.navy)
                    Text("Cổng kết nối: \(sensor.port.isEmpty ? "Chưa xác định" : sensor.port)")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(current.map { "\($0.fixed(2)) \(sensor.displayUnit)" } ?? "-- \(sensor.displayUnit)")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)

                    // Chỉ số đồng hồ tổng chỉ có ý nghĩa với cảm biến lưu lượng.
                    if sensor.isFlow, let total = readings.totalMeter {
                        Text("Chỉ số tổng").font(.system(size: 9)).foregroundStyle(Theme.muted)
                        Text("\(total.meterReading) m³")
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.green)
                    }
                }
            }
            Sparkline(values: series, color: sensor.isFlow ? Theme.green : Theme.blue)
        }
        .padding(.vertical, 4)
    }
}
