import XCTest
@testable import Mach

final class ShellExecutorTests: XCTestCase {
    func testRunEchoCommand() async throws {
        let result = try await ShellExecutor.run("/bin/echo", arguments: ["hello"])
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
        XCTAssertEqual(result.exitCode, 0)
    }
    func testRunFailingCommand() async throws {
        let result = try await ShellExecutor.run("/usr/bin/false")
        XCTAssertNotEqual(result.exitCode, 0)
    }
    func testRunCommandWithOutput() async throws {
        let result = try await ShellExecutor.run("/usr/bin/uname", arguments: ["-s"])
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "Darwin")
        XCTAssertEqual(result.exitCode, 0)
    }
    func testShellCommandConvenience() async throws {
        let result = try await ShellExecutor.shell("echo 'test output'")
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "test output")
    }
    func testToolExists() {
        XCTAssertTrue(ShellExecutor.toolExists("ls"))
        XCTAssertFalse(ShellExecutor.toolExists("nonexistent_tool_xyz_123"))
    }
}
