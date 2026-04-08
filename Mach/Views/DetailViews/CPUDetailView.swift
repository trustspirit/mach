import SwiftUI

struct CPUDetailView: View {
    @ObservedObject var monitor: CPUMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CPU Usage").font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.totalUsage)).font(.title2).fontWeight(.bold).foregroundStyle(.cyan)
                }
                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .cyan)
                    .frame(height: 120).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
                if !monitor.metrics.coreUsages.isEmpty {
                    Text("Per Core").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(monitor.metrics.coreUsages.enumerated()), id: \.offset) { index, usage in
                        HStack {
                            Text("Core \(index)").font(.caption).frame(width: 50, alignment: .leading)
                            ProgressView(value: usage, total: 100).tint(.cyan)
                            Text(String(format: "%.0f%%", usage)).font(.caption).monospacedDigit().frame(width: 36, alignment: .trailing)
                        }
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
