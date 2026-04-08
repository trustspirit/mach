import Foundation

struct PackageCleaner: Cleaner {
    let id: String
    let name: String
    let category: CleanCategory = .developer
    let requiresRoot = false

    private let toolName: String
    private let cleanCommand: String
    private let cachePath: String?

    func checkAvailable() async -> Bool {
        await ShellExecutor.toolExists(toolName)
    }

    func scanSize() async -> UInt64 {
        guard let path = cachePath else { return 0 }
        return directorySize(at: path)
    }

    func clean() async throws -> CleanResult {
        let result = try await ShellExecutor.shell(cleanCommand)
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: 0, success: success, error: success ? nil : result.errorOutput)
    }

    static var npm: PackageCleaner {
        PackageCleaner(
            id: "npm-cache",
            name: "npm Cache",
            toolName: "npm",
            cleanCommand: "npm cache clean --force",
            cachePath: NSHomeDirectory() + "/.npm/_cacache"
        )
    }

    static var yarn: PackageCleaner {
        PackageCleaner(
            id: "yarn-cache",
            name: "Yarn Cache",
            toolName: "yarn",
            cleanCommand: "yarn cache clean",
            cachePath: nil
        )
    }

    static var pip: PackageCleaner {
        PackageCleaner(
            id: "pip-cache",
            name: "pip Cache",
            toolName: "pip3",
            cleanCommand: "pip3 cache purge",
            cachePath: NSHomeDirectory() + "/Library/Caches/pip"
        )
    }
}
