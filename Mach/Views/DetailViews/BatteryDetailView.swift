import SwiftUI

struct BatteryDetailView: View {
    @ObservedObject var monitor: BatteryMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Battery").font(.title3).fontWeight(.bold)
                    Spacer()
                    Text("\(monitor.metrics.chargePercent)%").font(.title2).fontWeight(.bold).foregroundStyle(.green)
                }
                Text(monitor.metrics.statusText).font(.caption).foregroundStyle(.secondary)
                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .green)
                    .frame(height: 120).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
                HStack {
                    Text("Health").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.health)).font(.caption).monospacedDigit()
                }
                HStack {
                    Text("Cycle Count").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(monitor.metrics.cycleCount)").font(.caption).monospacedDigit()
                }
                Divider()
                if monitor.metrics.canTriggerFullCharge {
                    Button {
                        Task { try? await monitor.triggerFullCharge() }
                    } label: {
                        Label("Charge to Full", systemImage: "bolt.fill")
                    }.buttonStyle(.bordered).controlSize(.small)
                }
                Text("Energy Mode").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $monitor.currentEnergyMode) {
                    ForEach(EnergyMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }.pickerStyle(.segmented)
                .onChange(of: monitor.currentEnergyMode) { _, newMode in
                    Task { try? await monitor.setEnergyMode(newMode) }
                }
            }.padding(14)
        }
    }
}
