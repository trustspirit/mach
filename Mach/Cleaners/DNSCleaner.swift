import Foundation

struct DNSCleaner: Cleaner {
    let id = "dns-cache"
    let name = "DNS Cache"
    let category: CleanCategory = .system
    let requiresRoot = true

    func scanSize() async -> UInt64 {
        0
    }

    func clean() async throws -> CleanResult {
        let result = try await PrivilegeHelper.runWithPrivileges("dscacheutil -flushcache && killall -HUP mDNSResponder")
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: 0, success: success, error: success ? nil : result.errorOutput)
    }
}
