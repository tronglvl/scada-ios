import SwiftUI
import MapKit
import CoreLocation

/// `showsUserLocation` của Map không tự xin quyền — thiếu bước này chấm vị trí
/// của người dùng sẽ không bao giờ hiện. Giữ một CLLocationManager tối giản chỉ
/// để phát lời xin quyền khi mở tab Bản đồ.
private final class LocationPermission: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
}

struct MapScreen: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var location = LocationPermission()
    @State private var devices: [MapDevice] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 9.7845, longitude: 105.4700),  // Vị Thanh
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35))
    @State private var selected: MapDevice?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            // API dùng iOS 16 (Map(coordinateRegion:annotationItems:)) thay vì cú
            // pháp Map { } mới, vì bản mới chỉ có từ iOS 17.
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: devices) { device in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: device.vido,
                                                                longitude: device.kinhdo)) {
                    Button {
                        selected = device
                    } label: {
                        VStack(spacing: 0) {
                            Image(systemName: "drop.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(device.trangthai == 1 ? Theme.blue : Theme.muted)
                                .background(Circle().fill(.white).padding(3))
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 9))
                                .rotationEffect(.degrees(180))
                                .foregroundStyle(device.trangthai == 1 ? Theme.blue : Theme.muted)
                                .offset(y: -3)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            if let selected {
                MapDeviceCallout(device: selected) { self.selected = nil }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let error {
                Text(error)
                    .font(.system(size: 12)).foregroundStyle(.white)
                    .padding(10)
                    .background(Theme.danger, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 12)
            }

            if loading {
                ProgressView().tint(Theme.navy)
                    .padding(10).background(.white, in: Circle())
                    .padding(.bottom, 20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected?.id)
        .task {
            location.request()
            await load()
        }
        .onChange(of: app.lastUpdated) { _ in Task { await load() } }
    }

    private func load() async {
        guard let session = app.session else { return }
        loading = true
        defer { loading = false }
        do {
            let list = try await ApiClient.shared.mapDevices(companyId: session.idcty,
                                                             teamCode: session.teamCode)
            devices = list
            error = list.isEmpty ? "Chưa có thiết bị nào có toạ độ." : nil
            fitRegion(to: list)
        } catch {
            self.error = "Không tải được bản đồ: \(error.localizedDescription)"
        }
    }

    /// Canh khung nhìn ôm trọn các trạm, tránh phải kéo tay đi tìm.
    private func fitRegion(to list: [MapDevice]) {
        let points = list.filter { $0.vido != 0 && $0.kinhdo != 0 }
        guard !points.isEmpty else { return }
        let lats = points.map(\.vido), lons = points.map(\.kinhdo)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(maxLat - minLat, 0.01) * 1.4,
                                   longitudeDelta: max(maxLon - minLon, 0.01) * 1.4))
    }
}

private struct MapDeviceCallout: View {
    let device: MapDevice
    let onClose: () -> Void

    var body: some View {
        CardBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.ten.isEmpty ? device.id : device.ten)
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                        if !device.diachi.isEmpty {
                            Text("📍 \(device.diachi)").font(.system(size: 11))
                                .foregroundStyle(Theme.muted).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(Theme.muted)
                    }
                }

                Divider().overlay(Theme.softLine)

                HStack(spacing: 12) {
                    MetricCell(label: "Áp lực", value: device.latestPressure.fixed(2), unit: "kg/cm²", color: Theme.blue)
                    MetricCell(label: "Lưu lượng", value: device.latestFlow.fixed(2), unit: "m³/h", color: Theme.navy)
                    MetricCell(label: "Đồng hồ tổng",
                               value: device.totalMeter?.meterReading ?? "--",
                               unit: "m³", color: Theme.green)
                }
            }
        }
    }
}

private struct MetricCell: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 16, weight: .bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(unit).font(.system(size: 9)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
