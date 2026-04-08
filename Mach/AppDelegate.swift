import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var hostingView: NSHostingView<AnyView>!
    let monitorManager = MonitorManager()
    private var appearanceObserver: NSObjectProtocol?
    private var escMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
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

        statusItem = NSStatusBar.system.statusItem(withLength: 52)
        if let button = statusItem.button {
            button.action = #selector(togglePanel)
            button.target = self
        }
        updateMenuBarIcon()

        // Observe battery changes for menu bar icon
        monitorManager.battery.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateMenuBarIcon() }
        }.store(in: &cancellables)

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

        let bat = monitorManager.battery.metrics
        let batPct = CGFloat(bat.chargePercent) / 100.0
        let ramPct = monitorManager.ram.metrics.usagePercent / 100.0
        let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let fgColor: NSColor = isDark ? .white.withAlphaComponent(0.75) : .black.withAlphaComponent(0.55)

        let eqW: CGFloat = 16
        let gap: CGFloat = 5
        let batBodyW: CGFloat = 21
        let imgW: CGFloat = eqW + gap + batBodyW + 4
        let imgH: CGFloat = 22

        let img = NSImage(size: NSSize(width: imgW, height: imgH), flipped: false) { _ in
            // --- Left: RAM equalizer bars ---
            let eqH: CGFloat = 14
            let eqY: CGFloat = (imgH - eqH) / 2
            let barW: CGFloat = 2.5
            let barGap: CGFloat = 1.5
            let frame = self.animFrame

            // Each bar has a phase-shifted sine wave height, scaled by RAM usage
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

                // Color intensity by RAM usage
                let color: NSColor = ramPct > 0.9 ? .systemRed
                    : ramPct > 0.7 ? .systemOrange
                    : .systemPurple
                color.withAlphaComponent(0.8).setFill()
                barPath.fill()
            }

            // --- Right: battery gauge ---
            let batX: CGFloat = eqW + gap
            let bodyH: CGFloat = 11
            let bodyY: CGFloat = (imgH - bodyH) / 2
            let cornerR: CGFloat = 2.5
            let fillPad: CGFloat = 1.6

            let bodyRect = NSRect(x: batX, y: bodyY, width: batBodyW, height: bodyH)
            let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: cornerR, yRadius: cornerR)
            fgColor.setStroke()
            bodyPath.lineWidth = 1.0
            bodyPath.stroke()

            let fillMaxW = batBodyW - fillPad * 2
            let fillW = max(fillMaxW * batPct, 1.5)
            let fillRect = NSRect(x: batX + fillPad, y: bodyY + fillPad, width: fillW, height: bodyH - fillPad * 2)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1, yRadius: 1)

            let fillColor: NSColor
            if bat.isPluggedIn { fillColor = .systemGreen }
            else if bat.chargePercent <= 10 { fillColor = .systemRed }
            else if bat.chargePercent <= 20 { fillColor = .systemOrange }
            else { fillColor = isDark ? .white.withAlphaComponent(0.8) : .black.withAlphaComponent(0.6) }
            fillColor.setFill()
            fillPath.fill()

            let tipX = batX + batBodyW + 1
            let tipH: CGFloat = 4.5
            let tipY = (imgH - tipH) / 2
            let tipPath = NSBezierPath(roundedRect: NSRect(x: tipX, y: tipY, width: 2, height: tipH), xRadius: 0.5, yRadius: 0.5)
            fgColor.setFill()
            tipPath.fill()

            if bat.isPluggedIn {
                let boltFont = NSFont.systemFont(ofSize: 8, weight: .bold)
                let boltStr = NSAttributedString(string: "⚡", attributes: [.font: boltFont, .foregroundColor: NSColor.white])
                let sz = boltStr.size()
                boltStr.draw(at: NSPoint(x: batX + (batBodyW - sz.width) / 2, y: bodyY + (bodyH - sz.height) / 2))
            }

            return true
        }
        img.isTemplate = false
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
