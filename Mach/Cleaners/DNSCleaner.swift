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
        let flushResult = try await PrivilegeHelper.runWithPrivileges("dscacheutil -flushcache")
        guard flushResult.exitCode == 0 else {
            return CleanResult(itemId: id, freedBytes: 0, success: false, error: flushResult.errorOutput)
        }
        // Best effort — mDNSResponder may be restarting; don't fail the whole operation
        _ = try? await PrivilegeHelper.runWithPrivileges("killall -HUP mDNSResponder")
        return CleanResult(itemId: id, freedBytes: 0, success: true, error: nil)
    }
}
