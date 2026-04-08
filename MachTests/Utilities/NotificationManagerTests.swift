import XCTest
@testable import Mach

final class NotificationManagerTests: XCTestCase {
    func testThresholdCPU() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .cpu, value: 50))
        XCTAssertTrue(manager.shouldAlert(metric: .cpu, value: 95))
    }
    func testThresholdRAM() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .ram, value: 80))
        XCTAssertTrue(manager.shouldAlert(metric: .ram, value: 92))
    }
    func testThresholdDisk() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .disk, value: 90))
        XCTAssertTrue(manager.shouldAlert(metric: .disk, value: 96))
    }
    func testThresholdBattery() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .battery, value: 30))
        XCTAssertTrue(manager.shouldAlert(metric: .battery, value: 10))
    }
    func testThresholdTemperature() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .temperature, value: 70))
        XCTAssertTrue(manager.shouldAlert(metric: .temperature, value: 96))
    }
    func testCooldownPreventsRepeatedAlerts() {
        let manager = NotificationManager()
        XCTAssertTrue(manager.shouldAlert(metric: .cpu, value: 95))
        manager.recordAlert(metric: .cpu)
        XCTAssertFalse(manager.shouldAlert(metric: .cpu, value: 95))
    }
}
