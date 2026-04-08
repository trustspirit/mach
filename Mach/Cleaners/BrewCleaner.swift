import Foundation

struct BrewCleaner: Cleaner {
    let id = "homebrew"
    let name = "Homebrew Cleanup"
    let category: CleanCategory = .developer
    let requiresRoot = false

    func checkAvailable() async -> Bool {
        await ShellExecutor.toolExists("brew")
    }

    func scanSize() async -> UInt64 {
        0
    }

    func clean() async throws -> CleanResult {
        let result = try await ShellExecutor.shell("brew cleanup --prune=all")
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: 0, success: success, error: success ? nil : result.errorOutput)
    }
}
