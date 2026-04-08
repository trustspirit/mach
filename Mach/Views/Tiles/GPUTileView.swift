import SwiftUI

struct GPUTileView: View {
    @ObservedObject var monitor: GPUMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("GPU").font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                if !monitor.metrics.name.isEmpty {
                    Text(monitor.metrics.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if monitor.metrics.temperature > 0 {
                    Text(String(format: "%.0f°C", monitor.metrics.temperature))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f%%", monitor.metrics.usage))
                    .font(.callout).fontWeight(.bold).foregroundStyle(.pink)
                if monitor.metrics.vramTotal > 0 {
                    Spacer()
                    Text("\(ByteFormatter.format(monitor.metrics.vramUsed))/\(ByteFormatter.format(monitor.metrics.vramTotal))")
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
                }
            }
            MiniGraphView(dataPoints: monitor.history, maxValue: 100, color: .pink)
                .frame(height: 28)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
