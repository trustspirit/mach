import SwiftUI

struct TileView: View {
    let title: String
    let value: String
    let percent: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
            Text(value).font(.title2).fontWeight(.bold).foregroundStyle(color)
            ProgressView(value: min(percent, 100), total: 100).tint(color)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
