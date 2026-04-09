import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var hostingView: NSHostingView<AnyView>!
    let monitorManager = MonitorManager()
    private var appearanceObserver: NSObjectProtocol?
    private var escMonitor: Any?
    private let panelWidth: CGFloat = 300

    // Animation state for RAM equalizer
    private var animTimer: Timer?
    private var animFrame: Int = 0
    private let barCount = 4

    func applicationDidFinishLaunching(_ notification: Notification) {
        syncAppearance()
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.syncAppearance()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: 24)
        if let button = statusItem.button {
            button.action = #selector(togglePanel)
            button.target = self
        }
        updateMenuBarIcon()


        // Start equalizer animation (always runs for menu bar visibility)
        startAnimTimer()

        let contentView = DashboardView()
            .environmentObject(monitorManager)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 100),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        hostingView = NSHostingView(rootView: AnyView(
            contentView
                .frame(width: panelWidth)
                .fixedSize(horizontal: false, vertical: true)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        ))
        panel.contentView = hostingView
        syncAppearance()
        monitorManager.start()

        // One-time passwordless setup on first launch
        if !PrivilegeHelper.isPasswordlessConfigured {
            Task { try? await PrivilegeHelper.installPasswordlessSudo() }
        }
    }

    private func startAnimTimer() {
        animTimer?.invalidate()
        let t = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animFrame = (self.animFrame + 1) % 8
            self.updateMenuBarIcon()
        }
        RunLoop.main.add(t, forMode: .common)
        animTimer = t
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        let ramPct = monitorManager.ram.metrics.usagePercent / 100.0

        // Template images: draw in black, macOS applies the correct tint automatically
        let color = NSColor.black

        let eqW: CGFloat = 16
        let imgW: CGFloat = eqW
        let imgH: CGFloat = 22

        let img = NSImage(size: NSSize(width: imgW, height: imgH), flipped: false) { _ in
            // RAM equalizer bars
            let eqH: CGFloat = 14
            let eqY: CGFloat = (imgH - eqH) / 2
            let barW: CGFloat = 2.5
            let barGap: CGFloat = 1.5
            let frame = self.animFrame

            for i in 0..<self.barCount {
                let phase = Double(frame + i * 2) * .pi / 4
                let wave = (sin(phase) + 1) / 2  // 0..1
                let minH: CGFloat = 2
                let maxH: CGFloat = eqH * CGFloat(min(ramPct + 0.15, 1.0))
                let h = minH + CGFloat(wave) * (maxH - minH)
                let x = CGFloat(i) * (barW + barGap)
                let y = eqY

                let barRect = NSRect(x: x, y: y, width: barW, height: h)
                let barPath = NSBezierPath(roundedRect: barRect, xRadius: 1, yRadius: 1)
                color.setFill()
                barPath.fill()
            }

            return true
        }
        img.isTemplate = true
        button.image = img
        button.imagePosition = .imageOnly
        button.title = ""
    }

    private func syncAppearance() {
        let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        NSApp.appearance = appearance
        panel?.appearance = appearance
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        syncAppearance()

        let fittingSize = hostingView.fittingSize
        let panelHeight = min(fittingSize.height, 600)
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let x = buttonFrame.midX - panelWidth / 2
        let y = buttonFrame.minY - panelHeight - 4
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel.orderFrontRegardless()
        monitorManager.popoverDidOpen()

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.closePanel(); return nil }
            return event
        }
    }

    private func closePanel() {
        panel.orderOut(nil)
        monitorManager.popoverDidClose()
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
    }
}
