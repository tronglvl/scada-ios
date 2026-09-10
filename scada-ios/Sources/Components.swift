import SwiftUI

/// Biểu đồ đường thu nhỏ. Vẽ bằng Path thay vì Charts để chạy được từ iOS 16
/// mà không phải kéo thêm phụ thuộc nào.
struct Sparkline: View {
    let values: [Double]
    var color: Color = Theme.blue
    var height: CGFloat = 74

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2 {
                let points = Array(values.suffix(Config.sparklinePoints))
                let minV = points.min() ?? 0
                let maxV = points.max() ?? 1
                let span = max(maxV - minV, 0.0001)

                ZStack {
                    linePath(points, in: geo.size, minV: minV, span: span)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    areaPath(points, in: geo.size, minV: minV, span: span)
                        .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0.0)],
                                             startPoint: .top, endPoint: .bottom))
                }
            } else {
                Text("Chưa đủ dữ liệu biểu đồ")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: height)
    }

    private func x(_ i: Int, _ count: Int, _ width: CGFloat) -> CGFloat {
        count <= 1 ? 0 : width * CGFloat(i) / CGFloat(count - 1)
    }

    private func y(_ v: Double, minV: Double, span: Double, _ height: CGFloat) -> CGFloat {
        height - CGFloat((v - minV) / span) * height
    }

    private func linePath(_ pts: [Double], in size: CGSize, minV: Double, span: Double) -> Path {
        Path { p in
            for (i, v) in pts.enumerated() {
                let point = CGPoint(x: x(i, pts.count, size.width),
                                    y: y(v, minV: minV, span: span, size.height))
                i == 0 ? p.move(to: point) : p.addLine(to: point)
            }
        }
    }

    private func areaPath(_ pts: [Double], in size: CGSize, minV: Double, span: Double) -> Path {
        Path { p in
            guard !pts.isEmpty else { return }
            p.move(to: CGPoint(x: 0, y: size.height))
            for (i, v) in pts.enumerated() {
                p.addLine(to: CGPoint(x: x(i, pts.count, size.width),
                                      y: y(v, minV: minV, span: span, size.height)))
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
        }
    }
}

struct CardBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct HeroBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.sky)
            }
            Spacer(minLength: 8)
            Text(badge)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.mint)
                .multilineTextAlignment(.trailing)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.navy)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct KpiTile: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 8, height: 8)
            Spacer().frame(height: 3)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(unit).font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

struct DeviceHeader: View {
    let device: DeviceSummary
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.tenNhaMay.isEmpty ? device.iddevice : device.tenNhaMay)
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                if !device.diaChi.isEmpty {
                    Text(device.diaChi).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Text("ID: \(device.iddevice)").font(.system(size: 10)).foregroundStyle(Theme.blue)
            }
            Spacer(minLength: 8)
            if let trailing { trailing }
        }
    }
}

/// Nhãn trạng thái kết nối, quy ước giống máy chủ: 4 = vô hiệu hóa, 1 = online.
struct StatusPill: View {
    let status: Int?

    var body: some View {
        let (text, color): (String, Color) = {
            switch status {
            case 4: return ("VÔ HIỆU HÓA", Theme.danger)
            case 1: return ("ĐANG ONLINE", Theme.green)
            default: return ("MẤT TÍN HIỆU", Theme.muted)
            }
        }()
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
