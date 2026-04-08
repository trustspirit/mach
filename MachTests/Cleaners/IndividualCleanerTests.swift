import XCTest
@testable import Mach

final class IndividualCleanerTests: XCTestCase {
    func testCacheCleanerScanSize() async {
        let cleaner = CacheCleaner()
        let size = await cleaner.scanSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testLogCleanerScanSize() async {
        let cleaner = LogCleaner()
        let size = await cleaner.scanSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testTempCleanerScanSize() async {
        let cleaner = TempCleaner()
        let size = await cleaner.scanSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testXcodeCleanerIsAvailable() {
        let cleaner = XcodeCleaner()
        let exists = FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData")
        XCTAssertEqual(cleaner.isAvailable, exists)
    }

    func testDockerCleanerAvailability() async {
        let cleaner = DockerCleaner()
        let available = await cleaner.checkAvailable()
        let expected = await ShellExecutor.toolExists("docker")
        XCTAssertEqual(available, expected)
    }

    func testBrewCleanerAvailability() async {
        let cleaner = BrewCleaner()
        let available = await cleaner.checkAvailable()
        let expected = await ShellExecutor.toolExists("brew")
        XCTAssertEqual(available, expected)
    }

    func testMemoryCleanerRequiresRoot() {
        XCTAssertTrue(MemoryCleaner().requiresRoot)
    }

    func testDNSCleanerRequiresRoot() {
        XCTAssertTrue(DNSCleaner().requiresRoot)
    }

    func testCacheCleanerDoesNotRequireRoot() {
        XCTAssertFalse(CacheCleaner().requiresRoot)
    }
}
