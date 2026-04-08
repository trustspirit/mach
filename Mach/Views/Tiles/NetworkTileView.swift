import SwiftUI

struct NetworkTileView: View {
    @ObservedObject var monitor: NetworkMonitor
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("NET").font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                HStack(spacing: 16) {
                    Label(monitor.metrics.uploadFormatted, systemImage: "arrow.up").font(.caption)
                    Label(monitor.metrics.downloadFormatted, systemImage: "arrow.down").font(.caption)
                }.foregroundStyle(.teal)
            }
            Spacer()
        }
        .padding(12).background(.quaternary.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
