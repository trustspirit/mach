import XCTest
@testable import Mach

final class DiskMonitorTests: XCTestCase {
    func testDiskMonitorInitialState() {
        let monitor = DiskMonitor()
        XCTAssertEqual(monitor.metrics.totalSpace, 0)
    }
    func testDiskMonitorUpdate() {
        let monitor = DiskMonitor()
        monitor.update()
        XCTAssertGreaterThan(monitor.metrics.totalSpace, 0)
        XCTAssertGreaterThan(monitor.metrics.usedSpace, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.usagePercent, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.usagePercent, 100)
    }
    func testDiskMonitorUsedLessThanTotal() {
        let monitor = DiskMonitor()
        monitor.update()
        XCTAssertLessThanOrEqual(monitor.metrics.usedSpace, monitor.metrics.totalSpace)
    }
}
