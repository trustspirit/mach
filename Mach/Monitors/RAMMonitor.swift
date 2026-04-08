import Foundation
import Darwin

final class RAMMonitor: ObservableObject {
    @Published var metrics = RAMMetrics()
    @Published var history: [Double] = []
    private let maxHistory = 60
    private let pageSize = UInt64(vm_kernel_page_size)

    func update() {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)
        let swap = UInt64(swapUsage.xsu_used)
        metrics = RAMMetrics(total: totalMemory, used: used, compressed: compressed, swap: swap, wired: wired, active: active, inactive: inactive)
        history.append(metrics.usagePercent)
        if history.count > maxHistory { history.removeFirst() }
    }
}
