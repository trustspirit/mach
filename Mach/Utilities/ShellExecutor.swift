import Foundation

struct ShellResult: Sendable {
    let output: String
    let errorOutput: String
    let exitCode: Int32
}

private final class PipeBuffer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "mach.shell.buffer")
    private var storage = Data()

    func append(_ data: Data) {
        queue.sync { storage.append(data) }
    }

    func consume() -> Data {
        queue.sync {
            let copy = storage
            storage = Data()
            return copy
        }
    }
}

enum ShellExecutor {
    static func run(_ executablePath: String, arguments: [String] = []) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let outBuffer = PipeBuffer()
            let errBuffer = PipeBuffer()

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty { outBuffer.append(chunk) }
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty { errBuffer.append(chunk) }
            }

            process.terminationHandler = { p in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                // Drain remaining bytes
                outBuffer.append(stdout.fileHandleForReading.readDataToEndOfFile())
                errBuffer.append(stderr.fileHandleForReading.readDataToEndOfFile())

                let result = ShellResult(
                    output: String(data: outBuffer.consume(), encoding: .utf8) ?? "",
                    errorOutput: String(data: errBuffer.consume(), encoding: .utf8) ?? "",
                    exitCode: p.terminationStatus
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    static func shell(_ command: String) async throws -> ShellResult {
        try await run("/bin/zsh", arguments: ["-c", command])
    }

    static func toolExists(_ name: String) async -> Bool {
        do {
            let result = try await run("/usr/bin/which", arguments: [name])
            return result.exitCode == 0
        } catch {
            return false
        }
    }
}
