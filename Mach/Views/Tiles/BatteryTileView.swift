import SwiftUI

struct BatteryTileView: View {
    @ObservedObject var monitor: BatteryMonitor
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BATTERY").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text("\(monitor.metrics.chargePercent)%").font(.title3).fontWeight(.bold).foregroundStyle(.green)
                        Text(monitor.metrics.statusText).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if monitor.metrics.cycleCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Health \(String(format: "%.0f%%", monitor.metrics.health))").font(.caption2).foregroundStyle(.secondary)
                        Text("Cycles \(monitor.metrics.cycleCount)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            ProgressView(value: Double(monitor.metrics.chargePercent), total: 100).tint(.green)
            if monitor.metrics.canTriggerFullCharge {
                Button { Task { try? await monitor.triggerFullCharge() } } label: {
                    Label("Full Charge", systemImage: "bolt.fill").font(.caption)
                }.buttonStyle(.bordered).controlSize(.small)
            }
            Picker("", selection: $monitor.currentEnergyMode) {
                ForEach(EnergyMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
            }.pickerStyle(.segmented)
            .onChange(of: monitor.currentEnergyMode) { _, newMode in
                Task { try? await monitor.setEnergyMode(newMode) }
            }
        }
        .padding(12).background(.quaternary.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
