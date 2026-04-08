import Foundation
import Darwin

final class CPUMonitor: ObservableObject {
    @Published var metrics = CPUMetrics()
    @Published var history: [Double] = []
    private let maxHistory = 60
    private var previousTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []
    private let hostPort: mach_port_t = mach_host_self()

    func update() {
        var numCPU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        let result = host_processor_info(hostPort, PROCESSOR_CPU_LOAD_INFO, &numCPU, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return }

        var newTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []

        for i in 0..<Int(numCPU) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt64(info[offset + Int(CPU_STATE_USER)])
            let system = UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[offset + Int(CPU_STATE_NICE)])
            newTicks.append((user, system, idle, nice))
        }

        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        guard !previousTicks.isEmpty, previousTicks.count == newTicks.count else {
            previousTicks = newTicks
            return
        }

        var coreUsages: [Double] = []
        var totalUser: UInt64 = 0, totalSystem: UInt64 = 0, totalIdle: UInt64 = 0, totalNice: UInt64 = 0
        var prevTotalUser: UInt64 = 0, prevTotalSystem: UInt64 = 0, prevTotalIdle: UInt64 = 0, prevTotalNice: UInt64 = 0

        for i in 0..<newTicks.count {
            let cur = newTicks[i]
            let prev = previousTicks[i]
            let usage = Self.calculateUsage(
                user: cur.user, system: cur.system, idle: cur.idle, nice: cur.nice,
                prevUser: prev.user, prevSystem: prev.system, prevIdle: prev.idle, prevNice: prev.nice
            )
            coreUsages.append(usage)
            totalUser += cur.user; totalSystem += cur.system; totalIdle += cur.idle; totalNice += cur.nice
            prevTotalUser += prev.user; prevTotalSystem += prev.system; prevTotalIdle += prev.idle; prevTotalNice += prev.nice
        }

        let totalUsage = Self.calculateUsage(
            user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice,
            prevUser: prevTotalUser, prevSystem: prevTotalSystem, prevIdle: prevTotalIdle, prevNice: prevTotalNice
        )
        previousTicks = newTicks

        metrics = CPUMetrics(totalUsage: totalUsage, coreUsages: coreUsages, temperature: 0)
        history.append(metrics.totalUsage)
        if history.count > maxHistory { history.removeFirst() }
    }

    static func calculateUsage(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64, prevUser: UInt64, prevSystem: UInt64, prevIdle: UInt64, prevNice: UInt64) -> Double {
        let userDelta = user &- prevUser
        let systemDelta = system &- prevSystem
        let idleDelta = idle &- prevIdle
        let niceDelta = nice &- prevNice
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else { return 0 }
        return Double(userDelta + systemDelta + niceDelta) / Double(totalDelta) * 100
    }
}
