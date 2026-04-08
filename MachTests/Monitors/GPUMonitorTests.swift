import XCTest
@testable import Mach

final class GPUMonitorTests: XCTestCase {
    func testGPUMonitorInitialState() {
        let monitor = GPUMonitor()
        XCTAssertEqual(monitor.metrics.usage, 0)
    }
    func testGPUMonitorUpdate() {
        let monitor = GPUMonitor()
        monitor.update()
        XCTAssertGreaterThanOrEqual(monitor.metrics.usage, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.usage, 100)
    }
}
