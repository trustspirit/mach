import Foundation

enum PrivilegeHelper {
    static func runWithPrivileges(_ command: String) async throws -> ShellResult {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return try await ShellExecutor.run("/usr/bin/osascript", arguments: ["-e", script])
    }
}
