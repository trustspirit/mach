import Foundation
import Darwin

struct MemoryCleaner: Cleaner {
    let id = "memory"
    let name = "Memory Purge"
    let category: CleanCategory = .system
    let requiresRoot = true

    func scanSize() async -> UInt64 {
        0
    }

    func clean() async throws -> CleanResult {
        let purgeableBefore = Self.currentPurgeableMemory()
        let result = try await PrivilegeHelper.runWithPrivileges("purge")
        let success = result.exitCode == 0
        let purgeableAfter = Self.currentPurgeableMemory()
        let freed: UInt64 = purgeableBefore > purgeableAfter ? purgeableBefore - purgeableAfter : 0
        return CleanResult(itemId: id, freedBytes: freed, success: success, error: success ? nil : result.errorOutput)
    }

    private static func currentPurgeableMemory() -> UInt64 {
        let pageSize = UInt64(vm_kernel_page_size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(stats.purgeable_count) * pageSize
    }
}
