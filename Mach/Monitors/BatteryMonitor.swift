import Foundation
import AppKit
import IOKit.ps

enum EnergyMode: String, CaseIterable {
    case lowPower = "Low Power"
    case automatic = "Automatic"
}

/// Isolated state for energy hog detection — only accessed from hogQueue
private final class HogState {
    var hitCount: [String: Int] = [:]
    var lastCpu: [String: Double] = [:]
    let appearThreshold = 2
    let decay = 1
    let removeThreshold = -4
}

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published var metrics = BatteryMetrics()
    @Published var history: [Double] = []
    private let maxHistory = 60
    @Published var currentEnergyMode: EnergyMode = .automatic
    private var hasLoadedEnergyMode = false
    private var isSettingEnergyMode = false

    // Hog detection runs on a serial queue with its own isolated state
    private let hogQueue = DispatchQueue(label: "mach.energyhogs", qos: .utility)
    private let hogState = HogState()

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
            let rawMaxCap = IORegistryEntryCreateCFProperty(service, "AppleRawMaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
            let maxCap = rawMaxCap ?? (IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int)
            if let maxCap = maxCap,
               let designCap = IORegistryEntryCreateCFProperty(service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
               designCap > 0, maxCap > 100 { health = Double(maxCap) / Double(designCap) * 100 }
            if let optimized = IORegistryEntryCreateCFProperty(service, "OptimizedBatteryChargingEngaged" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool {
                isOptimizedHolding = optimized && isPluggedIn && !isCharging
            }
            IOObjectRelease(service)
        }

        var timeRemaining: Int? = nil
        if !isPluggedIn, let tte = timeToEmpty, tte > 0 { timeRemaining = tte }

        metrics = BatteryMetrics(chargePercent: currentCapacity, isCharging: isCharging, isPluggedIn: isPluggedIn, cycleCount: cycleCount, health: min(health, 100), timeRemaining: timeRemaining, isOptimizedHolding: isOptimizedHolding, energyHogs: metrics.energyHogs)
        history.append(Double(metrics.chargePercent))
        if history.count > maxHistory { history.removeFirst() }

        if !hasLoadedEnergyMode {
            hasLoadedEnergyMode = true
            Task { await loadCurrentEnergyMode() }
        }
    }

    /// Snapshot running apps on main thread, then detect hogs on background queue
    func scheduleHogDetection() {
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> (pid: pid_t, name: String)? in
            guard app.activationPolicy == .regular, let name = app.localizedName else { return nil }
            return (app.processIdentifier, name)
        }
        let state = hogState
        hogQueue.async { [weak self] in
            let hogs = Self.detectEnergyHogs(apps: apps, state: state)
            DispatchQueue.main.async { self?.metrics.energyHogs = hogs }
        }
    }

    private func loadCurrentEnergyMode() async {
        let mode = await detectEnergyMode()
        currentEnergyMode = mode
    }

    nonisolated private func detectEnergyMode() async -> EnergyMode {
        guard let result = try? await ShellExecutor.shell("pmset -g") else { return .automatic }
        let output = result.output
        if output.contains("lowpowermode         1") { return .lowPower }
        return .automatic
    }

    func triggerFullCharge() async throws {
        guard metrics.isOptimizedHolding, metrics.isPluggedIn else { return }
        _ = try await PrivilegeHelper.runWithPrivileges("pmset -a optimizedbatterycharging 0")
        try await Task.sleep(for: .seconds(2))
        _ = try await PrivilegeHelper.runWithPrivileges("pmset -a optimizedbatterycharging 1")
    }

    func setEnergyMode(_ mode: EnergyMode) async throws {
        guard !isSettingEnergyMode else { return }
        guard mode != currentEnergyMode else { return }
        isSettingEnergyMode = true
        defer { isSettingEnergyMode = false }

        let command: String
        switch mode {
        case .lowPower: command = "pmset -a lowpowermode 1"
        case .automatic: command = "pmset -a lowpowermode 0"
        }
        _ = try await PrivilegeHelper.runWithPrivileges(command)
        currentEnergyMode = mode
    }

    // MARK: - Energy Hogs (runs on hogQueue with isolated HogState)

    private static func detectEnergyHogs(apps: [(pid: pid_t, name: String)], state: HogState) -> [EnergyHog] {
        guard !apps.isEmpty else { state.hitCount.removeAll(); state.lastCpu.removeAll(); return [] }

        let pidList = apps.map { "\($0.pid)" }.joined(separator: ",")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-p", pidList, "-o", "pid=,pcpu="]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return [] }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let pidMap = Dictionary(uniqueKeysWithValues: apps.map { ($0.pid, $0.name) })
        var currentHogs = Set<String>()
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let pid = Int32(parts[0]), let cpu = Double(parts[1]), cpu >= 10,
                  let name = pidMap[pid] else { continue }
            currentHogs.insert(name)
            state.lastCpu[name] = cpu
        }

        for name in currentHogs {
            state.hitCount[name, default: 0] += 1
        }
        for name in state.hitCount.keys where !currentHogs.contains(name) {
            state.hitCount[name, default: 0] -= state.decay
        }
        state.hitCount = state.hitCount.filter { $0.value > state.removeThreshold }
        for name in state.lastCpu.keys where state.hitCount[name] == nil {
            state.lastCpu.removeValue(forKey: name)
        }

        let stable = state.hitCount.filter { $0.value >= state.appearThreshold }.keys
        let result = stable.compactMap { name -> EnergyHog? in
            guard let cpu = state.lastCpu[name] else { return nil }
            return EnergyHog(name: name, cpuPercent: cpu)
        }
        return result.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(3).map { $0 }
    }
}
