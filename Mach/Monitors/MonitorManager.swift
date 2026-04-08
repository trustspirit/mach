import Foundation

@MainActor
final class MonitorManager: ObservableObject {
    let cpu = CPUMonitor()
    let ram = RAMMonitor()
    let gpu = GPUMonitor()
    let disk = DiskMonitor()
    let network = NetworkMonitor()
    let battery = BatteryMonitor()
    let notifications = NotificationManager()

    @Published private(set) var isRunning = false
    private var timer: Timer?
    private let openInterval: TimeInterval = 1.0
    private let closedInterval: TimeInterval = 10.0

    func start() {
        isRunning = true
        updateAll()
        notifications.requestPermission()
        scheduleTimer(interval: closedInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func popoverDidOpen() {
        scheduleTimer(interval: openInterval)
    }

    func popoverDidClose() {
        scheduleTimer(interval: closedInterval)
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateAll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func updateAll() {
        cpu.update()
        ram.update()
        gpu.update()
        disk.update()
        network.update()
        battery.update()
        notifications.checkThresholds(manager: self)
        // Snapshot apps on main, detect hogs on background queue
        battery.scheduleHogDetection()
    }
}
