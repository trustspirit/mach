import Foundation
import IOKit.ps

enum EnergyMode: String, CaseIterable {
    case lowPower = "Low Power"
    case automatic = "Automatic"
    case highPerformance = "High Performance"
}

final class BatteryMonitor: ObservableObject {
    @Published var metrics = BatteryMetrics()
    @Published var history: [Double] = []
    private let maxHistory = 60
    @Published var currentEnergyMode: EnergyMode = .automatic

    func update() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let firstSource = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, firstSource as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else { return }

        let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int

        var cycleCount = 0
        var health: Double = 0
        var isOptimizedHolding = false

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != IO_OBJECT_NULL {
            if let val = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int { cycleCount = val }
            if let maxCap = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
               let designCap = IORegistryEntryCreateCFProperty(service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
               designCap > 0 { health = Double(maxCap) / Double(designCap) * 100 }
            if let optimized = IORegistryEntryCreateCFProperty(service, "OptimizedBatteryChargingEngaged" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool {
                isOptimizedHolding = optimized && isPluggedIn && !isCharging
            }
            IOObjectRelease(service)
        }

        var timeRemaining: Int? = nil
        if !isPluggedIn, let tte = timeToEmpty, tte > 0 { timeRemaining = tte }

        metrics = BatteryMetrics(chargePercent: currentCapacity, isCharging: isCharging, isPluggedIn: isPluggedIn, cycleCount: cycleCount, health: min(health, 100), timeRemaining: timeRemaining, isOptimizedHolding: isOptimizedHolding)
        history.append(Double(metrics.chargePercent))
        if history.count > maxHistory { history.removeFirst() }
    }

    func triggerFullCharge() async throws {
        guard metrics.canTriggerFullCharge else { return }
        _ = try await PrivilegeHelper.runWithPrivileges("pmset -a optimizedbatterycharging 0 && sleep 2 && pmset -a optimizedbatterycharging 1")
    }

    func getCurrentEnergyMode() async -> EnergyMode {
        guard let result = try? await ShellExecutor.shell("pmset -g") else { return .automatic }
        let output = result.output
        if output.contains("lowpowermode         1") { return .lowPower }
        else if output.contains("highpowermode        1") { return .highPerformance }
        return .automatic
    }

    func setEnergyMode(_ mode: EnergyMode) async throws {
        let command: String
        switch mode {
        case .lowPower: command = "pmset -a lowpowermode 1 && pmset -a highpowermode 0"
        case .automatic: command = "pmset -a lowpowermode 0 && pmset -a highpowermode 0"
        case .highPerformance: command = "pmset -a lowpowermode 0 && pmset -a highpowermode 1"
        }
        _ = try await PrivilegeHelper.runWithPrivileges(command)
        currentEnergyMode = mode
    }
}
