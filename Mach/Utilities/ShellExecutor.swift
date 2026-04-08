import Foundation

struct ShellResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
}

enum ShellExecutor {
    static func run(_ executablePath: String, arguments: [String] = []) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        return ShellResult(
            output: String(data: outData, encoding: .utf8) ?? "",
            errorOutput: String(data: errData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    static func shell(_ command: String) async throws -> ShellResult {
        try await run("/bin/zsh", arguments: ["-c", command])
    }

    static func toolExists(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
