import Foundation
import Darwin

final class CPUMonitor: ObservableObject {
    @Published var metrics = CPUMetrics()
    @Published var history: [Double] = []
    private let maxHistory = 60
    private var previousTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []

    func update() {
        var numCPU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPU, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return }

        var coreUsages: [Double] = []
        var newTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []
        var totalUser: UInt64 = 0, totalSystem: UInt64 = 0, totalIdle: UInt64 = 0, totalNice: UInt64 = 0

        for i in 0..<Int(numCPU) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt64(info[offset + Int(CPU_STATE_USER)])
            let system = UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[offset + Int(CPU_STATE_NICE)])
            totalUser += user; totalSystem += system; totalIdle += idle; totalNice += nice
            let prev: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) = i < previousTicks.count ? previousTicks[i] : (0, 0, 0, 0)
            let usage = Self.calculateUsage(user: user, system: system, idle: idle, nice: nice, prevUser: prev.user, prevSystem: prev.system, prevIdle: prev.idle, prevNice: prev.nice)
            coreUsages.append(usage)
            newTicks.append((user, system, idle, nice))
        }

        let prevTotal = previousTicks.reduce((UInt64(0), UInt64(0), UInt64(0), UInt64(0))) {
            ($0.0 + $1.user, $0.1 + $1.system, $0.2 + $1.idle, $0.3 + $1.nice)
        }
        let totalUsage = Self.calculateUsage(user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice, prevUser: prevTotal.0, prevSystem: prevTotal.1, prevIdle: prevTotal.2, prevNice: prevTotal.3)
        previousTicks = newTicks

        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        metrics = CPUMetrics(totalUsage: totalUsage, coreUsages: coreUsages, temperature: 0)
        history.append(metrics.totalUsage)
        if history.count > maxHistory { history.removeFirst() }
    }

    static func calculateUsage(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64, prevUser: UInt64, prevSystem: UInt64, prevIdle: UInt64, prevNice: UInt64) -> Double {
        let userDelta = user - prevUser
        let systemDelta = system - prevSystem
        let idleDelta = idle - prevIdle
        let niceDelta = nice - prevNice
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else { return 0 }
        return Double(userDelta + systemDelta + niceDelta) / Double(totalDelta) * 100
    }
}
