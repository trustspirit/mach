import SwiftUI

struct RAMTileView: View {
    @ObservedObject var monitor: RAMMonitor
    @State private var isPurging = false
    @State private var purgeResult: Bool?

    private var purgeable: UInt64 {
        monitor.metrics.inactive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("RAM").font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                Text("\(ByteFormatter.format(monitor.metrics.used)) / \(ByteFormatter.format(monitor.metrics.total))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(String(format: "%.0f%%", monitor.metrics.usagePercent))
                .font(.callout).fontWeight(.bold).foregroundStyle(.purple)
            MiniGraphView(dataPoints: monitor.history, maxValue: 100, color: .purple)
                .frame(height: 28)
            HStack(spacing: 0) {
                if isPurging {
                    Spacer()
                    ProgressView().controlSize(.mini)
                    Text(" Purging…").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                } else if let success = purgeResult {
                    Spacer()
                    Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption2).foregroundStyle(success ? .green : .red)
                    Text(success ? " Purged" : " Failed").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Button {
                        isPurging = true
                        purgeResult = nil
                        Task {
                            let success: Bool
                            do {
                                let result = try await PrivilegeHelper.runWithPrivileges("purge")
                                success = result.exitCode == 0
                            } catch { success = false }
                            await MainActor.run { isPurging = false; purgeResult = success }
                            // Reset after 3 seconds so button reappears with updated purgeable size
                            try? await Task.sleep(for: .seconds(3))
                            await MainActor.run { purgeResult = nil }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "memory").font(.caption2)
                            Text("Purge").font(.caption2)
                            Text("·").foregroundStyle(.secondary)
                            Text(ByteFormatter.format(purgeable)).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                }
            }.frame(height: 20)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
