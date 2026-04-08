import SwiftUI

struct DiskTileView: View {
    @ObservedObject var monitor: DiskMonitor
    var body: some View {
        TileView(title: "DISK", value: String(format: "%.0f%%", monitor.metrics.usagePercent), percent: monitor.metrics.usagePercent, color: .blue)
    }
}
