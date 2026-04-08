import XCTest
@testable import Mach

final class NetworkMonitorTests: XCTestCase {
    func testNetworkMonitorInitialState() {
        let monitor = NetworkMonitor()
        XCTAssertEqual(monitor.metrics.uploadSpeed, 0)
        XCTAssertEqual(monitor.metrics.downloadSpeed, 0)
    }
    func testNetworkMonitorUpdate() {
        let monitor = NetworkMonitor()
        monitor.update()
        monitor.update()
        XCTAssertGreaterThanOrEqual(monitor.metrics.uploadSpeed, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.downloadSpeed, 0)
    }
    func testNetworkMonitorHasInterface() {
        let monitor = NetworkMonitor()
        monitor.update()
        XCTAssertFalse(monitor.metrics.interfaceName.isEmpty)
    }
}
