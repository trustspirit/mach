import SwiftUI

enum DashboardRoute: Hashable {
    case dashboard, cpuDetail, gpuDetail, ramDetail, diskDetail, networkDetail, batteryDetail, cleaner, settings
}

struct DashboardView: View {
    @EnvironmentObject var manager: MonitorManager
    @State private var route: DashboardRoute = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch route {
            case .dashboard: dashboardContent
            case .cleaner: CleanerView(onBack: { route = .dashboard })
            case .settings: SettingsView().environmentObject(manager)
            case .cpuDetail: CPUDetailView(monitor: manager.cpu, onBack: { route = .dashboard })
            case .gpuDetail: GPUDetailView(monitor: manager.gpu, onBack: { route = .dashboard })
            case .ramDetail: RAMDetailView(monitor: manager.ram, onBack: { route = .dashboard })
            case .diskDetail: DiskDetailView(monitor: manager.disk, onBack: { route = .dashboard })
            case .networkDetail: NetworkDetailView(monitor: manager.network, onBack: { route = .dashboard })
            case .batteryDetail: BatteryDetailView(monitor: manager.battery, onBack: { route = .dashboard })
            }
        }.frame(width: 320, height: 480)
    }

    private var header: some View {
        HStack {
            if route != .dashboard {
                Button { route = .dashboard } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
            }
            Text("Mach").font(.headline).fontWeight(.bold)
            Spacer()
            if route == .dashboard {
                Button { route = .cleaner } label: { Image(systemName: "paintbrush") }.buttonStyle(.plain).help("Clean")
                Button { route = .settings } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).help("Settings")
                Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }.buttonStyle(.plain).help("Quit Mach")
            }
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    CPUTileView(monitor: manager.cpu).onTapGesture { route = .cpuDetail }
                    GPUTileView(monitor: manager.gpu).onTapGesture { route = .gpuDetail }
                    RAMTileView(monitor: manager.ram).onTapGesture { route = .ramDetail }
                    DiskTileView(monitor: manager.disk).onTapGesture { route = .diskDetail }
                }
                NetworkTileView(monitor: manager.network).onTapGesture { route = .networkDetail }
                BatteryTileView(monitor: manager.battery).onTapGesture { route = .batteryDetail }
            }.padding(10)
        }
    }
}
