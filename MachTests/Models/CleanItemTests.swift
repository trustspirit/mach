import XCTest
@testable import Mach

final class CleanItemTests: XCTestCase {
    func testCleanItemFormatSize() {
        let item = CleanItem(id: "system-cache", name: "System Cache", category: .system, sizeBytes: 1_258_291_200, requiresRoot: false)
        XCTAssertEqual(item.formattedSize, "1.2 GB")
    }

    func testCleanItemMBFormatting() {
        let item = CleanItem(id: "app-logs", name: "App Logs", category: .system, sizeBytes: 356_515_840, requiresRoot: false)
        XCTAssertEqual(item.formattedSize, "340.0 MB")
    }

    func testCleanItemNoSize() {
        let item = CleanItem(id: "dns-cache", name: "DNS Cache", category: .system, sizeBytes: nil, requiresRoot: true)
        XCTAssertEqual(item.formattedSize, "—")
    }

    func testCleanResultSuccess() {
        let result = CleanResult(itemId: "system-cache", freedBytes: 1_258_291_200, success: true, error: nil)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.formattedFreed, "1.2 GB")
    }

    func testCleanResultFailure() {
        let result = CleanResult(itemId: "docker", freedBytes: 0, success: false, error: "Docker not installed")
        XCTAssertFalse(result.success)
    }

    func testCleanItemCategoryGrouping() {
        let items = [
            CleanItem(id: "cache", name: "Cache", category: .system, sizeBytes: 100, requiresRoot: false),
            CleanItem(id: "xcode", name: "Xcode", category: .developer, sizeBytes: 200, requiresRoot: false),
            CleanItem(id: "logs", name: "Logs", category: .system, sizeBytes: 300, requiresRoot: false),
        ]
        XCTAssertEqual(items.filter { $0.category == .system }.count, 2)
        XCTAssertEqual(items.filter { $0.category == .developer }.count, 1)
    }
}
