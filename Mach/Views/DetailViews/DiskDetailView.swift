import SwiftUI

struct DiskDetailView: View {
    @ObservedObject var monitor: DiskMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Disk").font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.usagePercent)).font(.title2).fontWeight(.bold).foregroundStyle(.blue)
                }
                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .blue)
                    .frame(height: 120).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
                HStack {
                    Text("Used").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(CleanItem.formatBytes(monitor.metrics.usedSpace)) / \(CleanItem.formatBytes(monitor.metrics.totalSpace))").font(.caption).monospacedDigit()
                }
                HStack {
                    Text("Read Speed").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(NetworkMetrics.formatSpeed(monitor.metrics.readSpeed)).font(.caption).monospacedDigit()
                }
                HStack {
                    Text("Write Speed").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(NetworkMetrics.formatSpeed(monitor.metrics.writeSpeed)).font(.caption).monospacedDigit()
                }
            }.padding(14)
        }
    }
}
