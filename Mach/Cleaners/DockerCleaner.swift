import Foundation

struct DockerCleaner: Cleaner {
    let id = "docker"
    let name = "Docker Prune"
    let category: CleanCategory = .developer
    let requiresRoot = false

    var isAvailable: Bool {
        ShellExecutor.toolExists("docker")
    }

    func scanSize() async -> UInt64 {
        0
    }

    func clean() async throws -> CleanResult {
        let result = try await ShellExecutor.shell("docker system prune -f")
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: 0, success: success, error: success ? nil : result.errorOutput)
    }
}
