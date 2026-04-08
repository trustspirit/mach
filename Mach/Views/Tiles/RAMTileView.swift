import SwiftUI

struct RAMTileView: View {
    @ObservedObject var monitor: RAMMonitor
    var body: some View {
        TileView(title: "RAM", value: String(format: "%.0f%%", monitor.metrics.usagePercent), percent: monitor.metrics.usagePercent, color: .purple)
    }
}
