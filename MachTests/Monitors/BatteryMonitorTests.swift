import XCTest
@testable import Mach

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
    func testTriggerFullCharge() async {
        let monitor = BatteryMonitor()
        let canTrigger = monitor.metrics.canTriggerFullCharge
        XCTAssertFalse(canTrigger)
    }
    func testGetCurrentEnergyMode() async {
        let monitor = BatteryMonitor()
        let mode = await monitor.getCurrentEnergyMode()
        let validModes: [EnergyMode] = [.lowPower, .automatic, .highPerformance]
        XCTAssertTrue(validModes.contains(mode))
    }
}
