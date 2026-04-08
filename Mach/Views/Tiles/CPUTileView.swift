import SwiftUI

struct CPUTileView: View {
    @ObservedObject var monitor: CPUMonitor
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("CPU").font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                if !monitor.metrics.coreUsages.isEmpty {
                    Text("\(monitor.metrics.coreUsages.count) cores").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f%%", monitor.metrics.totalUsage))
                    .font(.callout).fontWeight(.bold).foregroundStyle(.cyan)
                if monitor.metrics.temperature > 0 {
                    Text(String(format: "%.0f°C", monitor.metrics.temperature))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            MiniGraphView(dataPoints: monitor.history, maxValue: 100, color: .cyan)
                .frame(height: 28)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
