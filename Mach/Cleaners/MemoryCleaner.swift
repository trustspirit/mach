import Foundation

struct MemoryCleaner: Cleaner {
    let id = "memory"
    let name = "Memory Purge"
    let category: CleanCategory = .system
    let requiresRoot = true

    func scanSize() async -> UInt64 {
        0
    }

    func clean() async throws -> CleanResult {
        let result = try await PrivilegeHelper.runWithPrivileges("purge")
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: 0, success: success, error: success ? nil : result.errorOutput)
    }
}
