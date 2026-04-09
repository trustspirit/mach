import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var manager: MonitorManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings").font(.title3).fontWeight(.bold)
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
                Divider()
                Toggle("Threshold Alerts", isOn: Binding(
                    get: { manager.notifications.alertsEnabled },
                    set: { manager.notifications.alertsEnabled = $0 }
                ))
                if manager.notifications.alertsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert Thresholds").font(.caption).foregroundStyle(.secondary)
                        thresholdRow("CPU", value: "90%")
                        thresholdRow("RAM", value: "90%")
                        thresholdRow("Disk", value: "95%")
                        thresholdRow("Temperature", value: "95°C")
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mach").font(.headline)
                    Text("Version 1.0.0").font(.caption).foregroundStyle(.secondary)
                    Text("System monitor & cleaner for developers").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(16)
        }.scrollIndicators(.hidden).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func thresholdRow(_ label: String, value: String) -> some View {
        HStack { Text(label).font(.caption); Spacer(); Text(value).font(.caption).monospacedDigit().foregroundStyle(.secondary) }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { launchAtLogin = !enabled }
    }
}
