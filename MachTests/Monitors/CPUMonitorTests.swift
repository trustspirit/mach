import XCTest
@testable import Mach

final class CPUMonitorTests: XCTestCase {
    func testCPUMonitorInitialState() {
        let monitor = CPUMonitor()
        XCTAssertEqual(monitor.metrics.totalUsage, 0)
        XCTAssertTrue(monitor.metrics.coreUsages.isEmpty)
    }
    func testCPUMonitorUpdate() {
        let monitor = CPUMonitor()
        monitor.update()
        XCTAssertGreaterThanOrEqual(monitor.metrics.totalUsage, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.totalUsage, 100)
        XCTAssertGreaterThan(monitor.metrics.coreUsages.count, 0)
    }
    func testCPUMonitorCoreUsagesInRange() {
        let monitor = CPUMonitor()
        monitor.update()
        for usage in monitor.metrics.coreUsages {
            XCTAssertGreaterThanOrEqual(usage, 0)
            XCTAssertLessThanOrEqual(usage, 100)
        }
    }
    func testCalculateUsage() {
        let usage = CPUMonitor.calculateUsage(user: 100, system: 50, idle: 850, nice: 0, prevUser: 0, prevSystem: 0, prevIdle: 0, prevNice: 0)
        XCTAssertEqual(usage, 15.0, accuracy: 0.1)
    }
    func testCalculateUsageZeroDelta() {
        let usage = CPUMonitor.calculateUsage(user: 100, system: 50, idle: 850, nice: 0, prevUser: 100, prevSystem: 50, prevIdle: 850, prevNice: 0)
        XCTAssertEqual(usage, 0)
    }
}
