import Foundation
import UserNotifications

enum AlertMetric: String, CaseIterable {
    case cpu, ram, disk, temperature
}

@MainActor
final class NotificationManager: ObservableObject {
    @Published var alertsEnabled = true
    private var thresholds: [AlertMetric: Double] = [.cpu: 90, .ram: 90, .disk: 95, .temperature: 95]
    private var lastAlertTime: [AlertMetric: Date] = [:]
    private let cooldownInterval: TimeInterval = 300

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func shouldAlert(metric: AlertMetric, value: Double) -> Bool {
        guard alertsEnabled, let threshold = thresholds[metric] else { return false }
        if let lastTime = lastAlertTime[metric], Date().timeIntervalSince(lastTime) < cooldownInterval { return false }
        return value >= threshold
    }

    func recordAlert(metric: AlertMetric) { lastAlertTime[metric] = Date() }

    func sendAlert(metric: AlertMetric, value: Double) {
        guard shouldAlert(metric: metric, value: value) else { return }
        recordAlert(metric: metric)
        let content = UNMutableNotificationContent()
        content.title = "Mach"; content.sound = .default
        switch metric {
        case .cpu: content.body = String(format: "CPU usage at %.0f%%", value)
        case .ram: content.body = String(format: "Memory usage at %.0f%%", value)
        case .disk: content.body = String(format: "Disk usage at %.0f%%", value)
        case .temperature: content.body = String(format: "Temperature at %.0f°C", value)
        }
        let request = UNNotificationRequest(identifier: "mach-\(metric.rawValue)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func checkThresholds(manager: MonitorManager) {
        sendAlert(metric: .cpu, value: manager.cpu.metrics.totalUsage)
        sendAlert(metric: .ram, value: manager.ram.metrics.usagePercent)
        sendAlert(metric: .disk, value: manager.disk.metrics.usagePercent)
        if manager.cpu.metrics.temperature > 0 { sendAlert(metric: .temperature, value: manager.cpu.metrics.temperature) }
    }
}
