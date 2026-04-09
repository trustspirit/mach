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
    private var clickMonitor: Any?
    private let panelWidth: CGFloat = 300

    // Cat animation state
    private var animTimer: Timer?
    private var cpuTimer: Timer?
    private var animFrame: Int = 0
    private var currentCpuPct: Double = 0
    private let catFrameCount = 5
    private let catFrames: [NSImage] = {
        (0..<5).compactMap { NSImage(named: "cat_\($0)") }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        syncAppearance()
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.syncAppearance()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePanel)
            button.target = self
        }
        updateMenuBarIcon()

        // Start cat animation (speed tied to CPU usage)
        startCpuTimer()
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

    private func startCpuTimer() {
        cpuTimer?.invalidate()
        let t = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.monitorManager.cpu.update()
            let load = self.monitorManager.cpu.metrics.totalUsage
            // RunCat formula: speed = max(1, load/5), interval = 500/speed ms
            let speed = max(1.0, load / 5.0)
            self.currentCpuPct = 0.5 / speed
        }
        RunLoop.main.add(t, forMode: .common)
        cpuTimer = t
        // Initial readings
        monitorManager.cpu.update()
        monitorManager.cpu.update()
        currentCpuPct = 0.5
    }

    private func startAnimTimer() {
        animTimer?.invalidate()
        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        let interval = currentCpuPct

        animTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.animFrame = (self.animFrame + 1) % self.catFrameCount
            self.updateMenuBarIcon()
            self.scheduleNextFrame()
        }
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        guard animFrame < catFrames.count else { return }

        let frame = catFrames[animFrame]
        let img = NSImage(size: NSSize(width: 28, height: 18))
        img.addRepresentation(frame.representations.first!)
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
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        panel.orderOut(nil)
        monitorManager.popoverDidClose()
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }
}
