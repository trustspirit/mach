import XCTest
@testable import Mach

final class CleanerManagerTests: XCTestCase {
    func testCleanerManagerHasAllItems() {
        XCTAssertEqual(CleanerManager().items.count, 11)
    }

    func testCleanerManagerSystemItems() {
        XCTAssertEqual(CleanerManager().items.filter { $0.category == .system }.count, 5)
    }

    func testCleanerManagerDeveloperItems() {
        XCTAssertEqual(CleanerManager().items.filter { $0.category == .developer }.count, 6)
    }

    func testQuickCleanItemIds() {
        let manager = CleanerManager()
        let quickIds = Set(manager.quickCleanItemIds)
        XCTAssertTrue(quickIds.contains("system-cache"))
        XCTAssertTrue(quickIds.contains("app-logs"))
        XCTAssertTrue(quickIds.contains("temp-files"))
        XCTAssertTrue(quickIds.contains("memory"))
        XCTAssertFalse(quickIds.contains("docker"))
    }
}
