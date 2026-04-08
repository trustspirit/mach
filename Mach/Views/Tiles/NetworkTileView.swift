import SwiftUI

struct NetworkTileView: View {
    @ObservedObject var monitor: NetworkMonitor
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "network").font(.caption).foregroundStyle(.teal)
            HStack(spacing: 10) {
                Label(monitor.metrics.uploadFormatted, systemImage: "arrow.up")
                    .font(.caption2).monospacedDigit()
                Label(monitor.metrics.downloadFormatted, systemImage: "arrow.down")
                    .font(.caption2).monospacedDigit()
            }.foregroundStyle(.teal)
            Spacer()
            if !monitor.metrics.interfaceName.isEmpty {
                Text(monitor.metrics.interfaceName).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10).background(.quaternary.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
