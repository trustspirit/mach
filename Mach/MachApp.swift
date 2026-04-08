import SwiftUI

@main
struct MachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView().environmentObject(appDelegate.monitorManager)
        }
    }
}
