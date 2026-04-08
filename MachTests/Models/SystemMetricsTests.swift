import XCTest
@testable import Mach

final class SystemMetricsTests: XCTestCase {
    func testCPUMetricsDefaults() {
        let cpu = CPUMetrics()
        XCTAssertEqual(cpu.totalUsage, 0)
        XCTAssertTrue(cpu.coreUsages.isEmpty)
        XCTAssertEqual(cpu.temperature, 0)
    }

    func testRAMMetrics() {
        let ram = RAMMetrics(total: 16_000_000_000, used: 10_000_000_000, compressed: 2_000_000_000, swap: 500_000_000, wired: 3_000_000_000, active: 5_000_000_000, inactive: 2_000_000_000)
        XCTAssertEqual(ram.usagePercent, 62.5, accuracy: 0.1)
    }

    func testGPUMetricsDefaults() {
        let gpu = GPUMetrics()
        XCTAssertEqual(gpu.usage, 0)
        XCTAssertEqual(gpu.vramUsed, 0)
        XCTAssertEqual(gpu.temperature, 0)
    }

    func testDiskMetrics() {
        let disk = DiskMetrics(totalSpace: 500_000_000_000, usedSpace: 250_000_000_000, readSpeed: 1_000_000, writeSpeed: 500_000)
        XCTAssertEqual(disk.usagePercent, 50.0, accuracy: 0.1)
    }

    func testNetworkMetrics() {
        let net = NetworkMetrics(uploadSpeed: 1_200_000, downloadSpeed: 5_400_000, interfaceName: "en0")
        XCTAssertEqual(net.uploadFormatted, "1.1 MB/s")
        XCTAssertEqual(net.downloadFormatted, "5.1 MB/s")
    }

    func testNetworkMetricsKBFormatting() {
        let net = NetworkMetrics(uploadSpeed: 500, downloadSpeed: 800, interfaceName: "en0")
        XCTAssertEqual(net.uploadFormatted, "500 B/s")
        XCTAssertEqual(net.downloadFormatted, "800 B/s")
    }

    func testNetworkMetricsKBRange() {
        let net = NetworkMetrics(uploadSpeed: 50_000, downloadSpeed: 900_000, interfaceName: "en0")
        XCTAssertEqual(net.uploadFormatted, "48.8 KB/s")
        XCTAssertEqual(net.downloadFormatted, "878.9 KB/s")
    }

    func testBatteryMetricsCharging() {
        let bat = BatteryMetrics(chargePercent: 87, isCharging: true, isPluggedIn: true, cycleCount: 342, health: 92.0, timeRemaining: nil, isOptimizedHolding: false)
        XCTAssertTrue(bat.isCharging)
        XCTAssertEqual(bat.statusText, "Charging")
    }

    func testBatteryMetricsDischarging() {
        let bat = BatteryMetrics(chargePercent: 65, isCharging: false, isPluggedIn: false, cycleCount: 342, health: 92.0, timeRemaining: 222, isOptimizedHolding: false)
        XCTAssertEqual(bat.statusText, "3:42 remaining")
    }

    func testBatteryMetricsOptimizedHolding() {
        let bat = BatteryMetrics(chargePercent: 80, isCharging: false, isPluggedIn: true, cycleCount: 342, health: 92.0, timeRemaining: nil, isOptimizedHolding: true)
        XCTAssertEqual(bat.statusText, "Holding at 80%")
        XCTAssertTrue(bat.canTriggerFullCharge)
    }

    func testBatteryMetricsFull() {
        let bat = BatteryMetrics(chargePercent: 100, isCharging: false, isPluggedIn: true, cycleCount: 342, health: 92.0, timeRemaining: nil, isOptimizedHolding: false)
        XCTAssertEqual(bat.statusText, "Fully charged")
        XCTAssertFalse(bat.canTriggerFullCharge)
    }
}
