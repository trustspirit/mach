import XCTest
@testable import Mach

@MainActor
final class BatteryMonitorTests: XCTestCase {
    func testBatteryMonitorInitialState() {
        let monitor = BatteryMonitor()
        XCTAssertEqual(monitor.metrics.chargePercent, 0)
        XCTAssertFalse(monitor.metrics.isCharging)
    }
    func testBatteryMonitorUpdate() {
        let monitor = BatteryMonitor()
        monitor.update()
        XCTAssertGreaterThanOrEqual(monitor.metrics.chargePercent, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.chargePercent, 100)
    }
    func testBatteryMonitorHealthRange() {
        let monitor = BatteryMonitor()
        monitor.update()
        XCTAssertGreaterThanOrEqual(monitor.metrics.health, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.health, 100)
    }
    func testEnergyModeDefault() {
        let monitor = BatteryMonitor()
        let validModes: [EnergyMode] = [.lowPower, .automatic]
        XCTAssertTrue(validModes.contains(monitor.currentEnergyMode))
    }
}
