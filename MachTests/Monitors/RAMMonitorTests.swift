import XCTest
@testable import Mach

final class RAMMonitorTests: XCTestCase {
    func testRAMMonitorInitialState() {
        let monitor = RAMMonitor()
        XCTAssertEqual(monitor.metrics.total, 0)
        XCTAssertEqual(monitor.metrics.used, 0)
    }
    func testRAMMonitorUpdate() {
        let monitor = RAMMonitor()
        monitor.update()
        XCTAssertGreaterThan(monitor.metrics.total, 0)
        XCTAssertGreaterThan(monitor.metrics.used, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.usagePercent, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.usagePercent, 100)
    }
    func testRAMMonitorComponentsNonNegative() {
        let monitor = RAMMonitor()
        monitor.update()
        XCTAssertGreaterThanOrEqual(monitor.metrics.wired, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.active, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.inactive, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.compressed, 0)
    }
}
