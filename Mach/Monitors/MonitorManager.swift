import Foundation
import Combine

final class MonitorManager: ObservableObject {
    let cpu = CPUMonitor()
    let ram = RAMMonitor()
    let gpu = GPUMonitor()
    let disk = DiskMonitor()
    let network = NetworkMonitor()
    let battery = BatteryMonitor()
    let notifications = NotificationManager()

    @Published private(set) var isRunning = false
    @Published private(set) var currentInterval: TimeInterval = 10.0
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let openInterval: TimeInterval = 1.0
    private let closedInterval: TimeInterval = 10.0

    init() {
        cpu.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        ram.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        gpu.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        disk.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        network.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        battery.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
    }

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
        currentInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateAll()
        }
    }

    private func updateAll() {
        cpu.update()
        ram.update()
        gpu.update()
        disk.update()
        network.update()
        battery.update()
        notifications.checkThresholds(manager: self)
    }
}
