import SwiftUI

struct CPUTileView: View {
    @ObservedObject var monitor: CPUMonitor
    var body: some View {
        TileView(title: "CPU", value: String(format: "%.0f%%", monitor.metrics.totalUsage), percent: monitor.metrics.totalUsage, color: .cyan)
    }
}
