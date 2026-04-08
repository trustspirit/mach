import XCTest
@testable import Mach

@MainActor
final class MonitorManagerTests: XCTestCase {
    func testMonitorManagerOwnsAllMonitors() {
        let manager = MonitorManager()
        XCTAssertNotNil(manager.cpu)
        XCTAssertNotNil(manager.ram)
        XCTAssertNotNil(manager.gpu)
        XCTAssertNotNil(manager.disk)
        XCTAssertNotNil(manager.network)
        XCTAssertNotNil(manager.battery)
    }
    func testMonitorManagerStartStop() {
        let manager = MonitorManager()
        XCTAssertFalse(manager.isRunning)
        manager.start()
        XCTAssertTrue(manager.isRunning)
        manager.stop()
        XCTAssertFalse(manager.isRunning)
    }
    func testMonitorManagerPopoverOpenClose() {
        let manager = MonitorManager()
        manager.start()
        // Verify popover open/close don't crash
        manager.popoverDidOpen()
        manager.popoverDidClose()
        manager.stop()
    }
}
