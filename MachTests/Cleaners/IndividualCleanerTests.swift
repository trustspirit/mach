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

    func testDockerCleanerAvailability() {
        let cleaner = DockerCleaner()
        XCTAssertEqual(cleaner.isAvailable, ShellExecutor.toolExists("docker"))
    }

    func testBrewCleanerAvailability() {
        let cleaner = BrewCleaner()
        XCTAssertEqual(cleaner.isAvailable, ShellExecutor.toolExists("brew"))
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
