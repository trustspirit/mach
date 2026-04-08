import SwiftUI

struct NetworkDetailView: View {
    @ObservedObject var monitor: NetworkMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Network").font(.title3).fontWeight(.bold)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Upload", systemImage: "arrow.up").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(monitor.metrics.uploadFormatted).font(.caption).monospacedDigit().foregroundStyle(.teal)
                    }
                    HistoryGraphView(dataPoints: monitor.uploadHistory, maxValue: max(monitor.uploadHistory.max() ?? 1, 1), color: .teal)
                        .frame(height: 80).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Download", systemImage: "arrow.down").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(monitor.metrics.downloadFormatted).font(.caption).monospacedDigit().foregroundStyle(.teal)
                    }
                    HistoryGraphView(dataPoints: monitor.downloadHistory, maxValue: max(monitor.downloadHistory.max() ?? 1, 1), color: .cyan)
                        .frame(height: 80).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                HStack {
                    Text("Interface").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(monitor.metrics.interfaceName).font(.caption).monospacedDigit()
                }
            }.padding(14)
        }
    }
}
