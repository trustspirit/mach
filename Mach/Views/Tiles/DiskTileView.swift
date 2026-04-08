import SwiftUI

struct DiskTileView: View {
    @ObservedObject var monitor: DiskMonitor

    private var freeSpace: UInt64 {
        monitor.metrics.totalSpace > monitor.metrics.usedSpace
            ? monitor.metrics.totalSpace - monitor.metrics.usedSpace : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("DISK").font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                Text("\(ByteFormatter.format(freeSpace)) free")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(String(format: "%.0f%%", monitor.metrics.usagePercent))
                .font(.callout).fontWeight(.bold).foregroundStyle(.blue)
            MiniGraphView(dataPoints: monitor.history, maxValue: 100, color: .blue)
                .frame(height: 28)
            HStack(spacing: 0) {
                Text("R ").font(.caption2).foregroundStyle(.secondary)
                Text(ByteFormatter.formatCompact(monitor.metrics.readSpeed))
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Text("W ").font(.caption2).foregroundStyle(.secondary)
                Text(ByteFormatter.formatCompact(monitor.metrics.writeSpeed))
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }.lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
