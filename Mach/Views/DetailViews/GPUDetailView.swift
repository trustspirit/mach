import SwiftUI

struct GPUDetailView: View {
    @ObservedObject var monitor: GPUMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("GPU Usage").font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.usage)).font(.title2).fontWeight(.bold).foregroundStyle(.pink)
                }
                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .pink)
                    .frame(height: 120).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
                if monitor.metrics.vramTotal > 0 {
                    HStack {
                        Text("VRAM").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(CleanItem.formatBytes(monitor.metrics.vramUsed)) / \(CleanItem.formatBytes(monitor.metrics.vramTotal))").font(.caption).monospacedDigit()
                    }
                }
                if monitor.metrics.temperature > 0 {
                    HStack {
                        Text("Temperature").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f\u{00B0}C", monitor.metrics.temperature)).font(.caption).monospacedDigit()
                    }
                }
            }.padding(14)
        }
    }
}
