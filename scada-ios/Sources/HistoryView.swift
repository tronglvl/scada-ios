import SwiftUI

/// Tab Lịch sử: chọn thiết bị rồi xem lại áp lực và lưu lượng theo khoảng ngày.
struct HistoryView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationStack {
            List {
                if app.devices.isEmpty {
                    Section {
                        EmptyStateBox(loading: app.isLoading, message: app.errorMessage)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                } else {
                    Section("Chọn thiết bị để xem lịch sử") {
                        ForEach(app.devices) { device in
                            NavigationLink {
                                HistoryDetailView(device: device)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.tenNhaMay.isEmpty ? device.iddevice : device.tenNhaMay)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text("ID: \(device.iddevice)")
                                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Lịch sử")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct HistoryDetailView: View {
    let device: DeviceSummary

    @State private var from = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var to = Date()
    @State private var rows: [MeasurementRecord] = []
    @State private var loading = false
    @State private var error: String?

    private var pressures: [Double] { rows.map(\.pressure) }
    private var flows: [Double] { rows.compactMap(\.flow) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                CardBox {
                    VStack(alignment: .leading, spacing: 10) {
                        DatePicker("Từ ngày", selection: $from, displayedComponents: .date)
                        DatePicker("Đến ngày", selection: $to, displayedComponents: .date)
                        Button {
                            Task { await load() }
                        } label: {
                            HStack {
                                if loading { ProgressView().tint(.white) }
                                Text(loading ? "Đang tải..." : "Xem dữ liệu")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Theme.navy).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .disabled(loading)
                    }
                    .environment(\.locale, Locale(identifier: "vi_VN"))
                    .font(.system(size: 13))
                    .tint(Theme.navy)
                }

                if let error {
                    CardBox { Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger) }
                }

                if !rows.isEmpty {
                    CardBox {
                        VStack(alignment: .leading, spacing: 8) {
                            SeriesHeader(title: "Áp lực", unit: "kg/cm²",
                                         values: pressures, color: Theme.blue)
                            Sparkline(values: pressures, color: Theme.blue, height: 90)
                        }
                    }

                    if !flows.isEmpty {
                        CardBox {
                            VStack(alignment: .leading, spacing: 8) {
                                SeriesHeader(title: "Lưu lượng", unit: "m³/h",
                                             values: flows, color: Theme.green)
                                Sparkline(values: flows, color: Theme.green, height: 90)
                            }
                        }
                    }

                    CardBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(rows.count) bản ghi")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                            // Bảng dài dễ làm chậm cuộn; chỉ liệt kê 60 mốc gần nhất.
                            ForEach(Array(rows.suffix(60).reversed().enumerated()), id: \.offset) { _, row in
                                HStack {
                                    Text(row.date.map { DateParsing.display.string(from: $0) } ?? row.measuredAt)
                                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                                    Spacer()
                                    Text("\(row.pressure.fixed(2)) kg/cm²")
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.blue)
                                    if let f = row.flow {
                                        Text("\(f.fixed(2)) m³/h")
                                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.green)
                                    }
                                }
                                Divider().overlay(Theme.softLine)
                            }
                        }
                    }
                } else if !loading {
                    EmptyStateBox(loading: false, message: "Chọn khoảng ngày rồi bấm Xem dữ liệu.")
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle(device.tenNhaMay.isEmpty ? device.iddevice : device.tenNhaMay)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            rows = try await ApiClient.shared.history(deviceId: device.iddevice, from: from, to: to)
            error = rows.isEmpty ? "Không có dữ liệu trong khoảng ngày đã chọn." : nil
        } catch {
            self.error = error.localizedDescription
            rows = []
        }
    }
}

private struct SeriesHeader: View {
    let title: String
    let unit: String
    let values: [Double]
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.navy)
            Spacer()
            if let min = values.min(), let max = values.max() {
                let avg = values.reduce(0, +) / Double(values.count)
                Text("min \(min.fixed(2)) · TB \(avg.fixed(2)) · max \(max.fixed(2)) \(unit)")
                    .font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
        }
    }
}
