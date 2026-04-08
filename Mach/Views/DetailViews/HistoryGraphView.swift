import SwiftUI

struct HistoryGraphView: View {
    let dataPoints: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ZStack {
                if dataPoints.count >= 2 {
                    Path { path in
                        let points = normalizedPoints(width: width, height: height)
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: height))
                        path.addLine(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: points.last!.x, y: height))
                        path.closeSubpath()
                    }.fill(color.opacity(0.15))

                    Path { path in
                        let points = normalizedPoints(width: width, height: height)
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }.stroke(color, lineWidth: 1.5)
                }
            }
        }
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard dataPoints.count >= 2, maxValue > 0 else { return [] }
        let step = width / CGFloat(dataPoints.count - 1)
        return dataPoints.enumerated().map { index, value in
            let x = CGFloat(index) * step
            let y = height - (CGFloat(value / maxValue) * height)
            return CGPoint(x: x, y: max(0, min(height, y)))
        }
    }
}
