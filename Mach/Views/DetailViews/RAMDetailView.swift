import SwiftUI

struct RAMDetailView: View {
    @ObservedObject var monitor: RAMMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Memory").font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.usagePercent)).font(.title2).fontWeight(.bold).foregroundStyle(.purple)
                }
                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .purple)
                    .frame(height: 120).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
                memoryRow("Used", bytes: monitor.metrics.used, color: .purple)
                memoryRow("Wired", bytes: monitor.metrics.wired, color: .orange)
                memoryRow("Active", bytes: monitor.metrics.active, color: .blue)
                memoryRow("Inactive", bytes: monitor.metrics.inactive, color: .gray)
                memoryRow("Compressed", bytes: monitor.metrics.compressed, color: .yellow)
                memoryRow("Swap", bytes: monitor.metrics.swap, color: .red)
                HStack {
                    Text("Total").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(CleanItem.formatBytes(monitor.metrics.total)).font(.caption).monospacedDigit()
                }
            }.padding(14)
        }
    }

    private func memoryRow(_ label: String, bytes: UInt64, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption)
            Spacer()
            Text(CleanItem.formatBytes(bytes)).font(.caption).monospacedDigit()
        }
    }
}
