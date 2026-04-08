import SwiftUI

struct GPUTileView: View {
    @ObservedObject var monitor: GPUMonitor
    var body: some View {
        TileView(title: "GPU", value: String(format: "%.0f%%", monitor.metrics.usage), percent: monitor.metrics.usage, color: .pink)
    }
}
