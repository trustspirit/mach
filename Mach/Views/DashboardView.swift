import SwiftUI

enum DashboardRoute: Hashable {
    case dashboard, cleaner, settings
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
            case .cleaner: CleanerView().frame(maxHeight: 400)
            case .settings: SettingsView().environmentObject(manager).frame(maxHeight: 400)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if route != .dashboard {
                Button { route = .dashboard } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                }.buttonStyle(.plain)
            }
            Text("Mach").font(.headline).fontWeight(.bold)
            Spacer()
            if route == .dashboard {
                HStack(spacing: 10) {
                    Button { route = .cleaner } label: {
                        Image(systemName: "paintbrush")
                            .font(.body.weight(.medium))
                    }.buttonStyle(.plain).help("Clean")
                    Button { route = .settings } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.medium))
                    }.buttonStyle(.plain).help("Settings")
                    Button { NSApplication.shared.terminate(nil) } label: {
                        Image(systemName: "power")
                            .font(.body.weight(.medium))
                    }.buttonStyle(.plain).help("Quit Mach")
                }
            }
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    CPUTileView(monitor: manager.cpu)
                    GPUTileView(monitor: manager.gpu)
                    RAMTileView(monitor: manager.ram)
                    DiskTileView(monitor: manager.disk)
                }
                NetworkTileView(monitor: manager.network)
                BatteryTileView(monitor: manager.battery)
            }.padding(12)
        }.scrollIndicators(.hidden)
    }
}
