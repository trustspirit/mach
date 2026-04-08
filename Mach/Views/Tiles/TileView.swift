import SwiftUI

struct TileView: View {
    let title: String
    let value: String
    let subtitle: String?
    let history: [Double]
    let maxValue: Double
    let color: Color

    init(title: String, value: String, subtitle: String? = nil, history: [Double], maxValue: Double, color: Color) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.history = history
        self.maxValue = maxValue
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                if let sub = subtitle {
                    Text(sub).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(value).font(.callout).fontWeight(.bold).foregroundStyle(color)
            MiniGraphView(dataPoints: history, maxValue: maxValue, color: color)
                .frame(height: 28)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MiniGraphView: View {
    let dataPoints: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pts = points(width: w, height: h)
            if pts.count >= 2 {
                ZStack {
                    // Fill
                    Path { path in
                        path.move(to: CGPoint(x: pts[0].x, y: h))
                        path.addLine(to: pts[0])
                        for i in 0..<(pts.count - 1) {
                            let cp = controlPoints(pts[i], pts[min(i+1, pts.count-1)])
                            path.addCurve(to: pts[i+1], control1: cp.0, control2: cp.1)
                        }
                        path.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        path.closeSubpath()
                    }.fill(color.opacity(0.12))
                    // Stroke
                    Path { path in
                        path.move(to: pts[0])
                        for i in 0..<(pts.count - 1) {
                            let cp = controlPoints(pts[i], pts[min(i+1, pts.count-1)])
                            path.addCurve(to: pts[i+1], control1: cp.0, control2: cp.1)
                        }
                    }.stroke(color, lineWidth: 1.2)
                }
            }
        }
    }

    private func points(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard dataPoints.count >= 2, maxValue > 0 else { return [] }
        let step = width / CGFloat(dataPoints.count - 1)
        return dataPoints.enumerated().map { i, v in
            let y = height - (CGFloat(min(v, maxValue) / maxValue) * height)
            return CGPoint(x: CGFloat(i) * step, y: max(0, min(height, y)))
        }
    }

    private func controlPoints(_ p0: CGPoint, _ p1: CGPoint) -> (CGPoint, CGPoint) {
        let dx = (p1.x - p0.x) * 0.3
        return (CGPoint(x: p0.x + dx, y: p0.y), CGPoint(x: p1.x - dx, y: p1.y))
    }
}
