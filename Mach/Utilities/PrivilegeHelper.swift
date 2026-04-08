import Foundation

enum PrivilegeHelper {
    private static let sudoersPath = "/etc/sudoers.d/mach"

    /// Run a single command with sudo (no shell wrapper). Splits "cmd arg1 arg2" into executable + args.
    /// For chained commands (&&), runs each sequentially.
    static func runWithPrivileges(_ command: String) async throws -> ShellResult {
        // Split on && for chained commands
        let commands = command.components(separatedBy: "&&").map { $0.trimmingCharacters(in: .whitespaces) }

        for cmd in commands {
            let parts = cmd.components(separatedBy: " ").filter { !$0.isEmpty }
            guard !parts.isEmpty else { continue }

            let executable = parts[0]
            let args = Array(parts.dropFirst())

            // Resolve full path if not absolute
            let fullPath = executable.hasPrefix("/") ? executable : resolveFullPath(executable)

            // Try sudo -n (passwordless) first
            let sudoArgs = ["-n", fullPath] + args
            let sudoResult = try await ShellExecutor.run("/usr/bin/sudo", arguments: sudoArgs)
            if sudoResult.exitCode != 0 {
                // Fallback to osascript for this specific sub-command
                let fallbackResult = try await osascriptFallback(cmd)
                if fallbackResult.exitCode != 0 { return fallbackResult }
            }
        }
        return ShellResult(output: "", errorOutput: "", exitCode: 0)
    }

    private static func resolveFullPath(_ name: String) -> String {
        let knownPaths: [String: String] = [
            "purge": "/usr/sbin/purge",
            "pmset": "/usr/bin/pmset",
            "dscacheutil": "/usr/sbin/dscacheutil",
            "killall": "/usr/bin/killall"
        ]
        return knownPaths[name] ?? "/usr/bin/\(name)"
    }

    private static func osascriptFallback(_ command: String) async throws -> ShellResult {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return try await ShellExecutor.run("/usr/bin/osascript", arguments: ["-e", script])
    }

    static var isPasswordlessConfigured: Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    static func installPasswordlessSudo() async throws -> Bool {
        let lines = [
            "# Mach - passwordless access for system monitor commands",
            "%admin ALL=(ALL) NOPASSWD: /usr/sbin/purge",
            "%admin ALL=(ALL) NOPASSWD: /usr/bin/pmset *",
            "%admin ALL=(ALL) NOPASSWD: /usr/sbin/dscacheutil *",
            "%admin ALL=(ALL) NOPASSWD: /usr/bin/killall -HUP mDNSResponder"
        ]
        let content = lines.joined(separator: "\n") + "\n"
        let tmpPath = NSTemporaryDirectory() + "mach_sudoers_\(UUID().uuidString)"
        try content.write(toFile: tmpPath, atomically: true, encoding: .utf8)

        let cmd = "cp '\(tmpPath)' '\(sudoersPath)' && chown root:wheel '\(sudoersPath)' && chmod 0440 '\(sudoersPath)' && rm -f '\(tmpPath)'"
        let escaped = cmd.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let result = try await ShellExecutor.run("/usr/bin/osascript", arguments: ["-e", script])
        return result.exitCode == 0
    }

    static func removePasswordlessSudo() async throws -> Bool {
        let script = "do shell script \"rm -f \(sudoersPath)\" with administrator privileges"
        let result = try await ShellExecutor.run("/usr/bin/osascript", arguments: ["-e", script])
        return result.exitCode == 0
    }
}
