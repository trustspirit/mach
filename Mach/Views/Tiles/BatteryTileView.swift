import SwiftUI

struct BatteryGaugeView: View {
    let percent: Int
    let isPluggedIn: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1.2)
                    .frame(width: 28, height: 13)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: max(CGFloat(percent) / 100 * 24, 2), height: 9)
                    .padding(.leading, 2)
                if isPluggedIn {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 13)
                }
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 2, height: 6)
        }
    }
}

struct BatteryTileView: View {
    @ObservedObject var monitor: BatteryMonitor

    private var gaugeColor: Color {
        if monitor.metrics.isPluggedIn { return .green }
        if monitor.metrics.chargePercent <= 10 { return .red }
        if monitor.metrics.chargePercent <= 20 { return .orange }
        return .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                BatteryGaugeView(
                    percent: monitor.metrics.chargePercent,
                    isPluggedIn: monitor.metrics.isPluggedIn,
                    color: gaugeColor
                )
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("\(monitor.metrics.chargePercent)%")
                            .font(.caption).fontWeight(.semibold)
                        Text(monitor.metrics.statusText)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if monitor.metrics.cycleCount > 0 {
                        HStack(spacing: 6) {
                            Text("Health \(String(format: "%.0f%%", monitor.metrics.health))")
                            Text("·")
                            Text("Cycles \(monitor.metrics.cycleCount)")
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if monitor.metrics.isOptimizedHolding {
                    Button {
                        Task { try? await monitor.triggerFullCharge() }
                    } label: {
                        Image(systemName: "bolt.fill").font(.caption2)
                    }.buttonStyle(.bordered).controlSize(.mini).help("Charge to Full")
                }
                Toggle("", isOn: Binding(
                    get: { monitor.currentEnergyMode == .lowPower },
                    set: { isOn in
                        Task { try? await monitor.setEnergyMode(isOn ? .lowPower : .automatic) }
                    }
                ))
                .toggleStyle(.switch).controlSize(.mini)
                .tint(.yellow)
                .labelsHidden()
                .help("Low Power Mode")
            }.padding(10)

            if !monitor.metrics.energyHogs.isEmpty {
                Divider().padding(.horizontal, 10)
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.caption2).foregroundStyle(.orange)
                        Text(monitor.metrics.energyHogs.map(\.name).joined(separator: ", "))
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(.quaternary.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
