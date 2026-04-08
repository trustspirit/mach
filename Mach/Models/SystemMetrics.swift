import Foundation

struct CPUMetrics {
    var totalUsage: Double = 0
    var coreUsages: [Double] = []
    var temperature: Double = 0
}

struct RAMMetrics {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var compressed: UInt64 = 0
    var swap: UInt64 = 0
    var wired: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0

    var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

struct GPUMetrics {
    var usage: Double = 0
    var vramUsed: UInt64 = 0
    var vramTotal: UInt64 = 0
    var temperature: Double = 0
    var name: String = ""
}

struct DiskMetrics {
    var totalSpace: UInt64 = 0
    var usedSpace: UInt64 = 0
    var readSpeed: UInt64 = 0
    var writeSpeed: UInt64 = 0

    var usagePercent: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }
}

struct NetworkMetrics {
    var uploadSpeed: UInt64 = 0
    var downloadSpeed: UInt64 = 0
    var interfaceName: String = ""

    var uploadFormatted: String { ByteFormatter.formatSpeed(uploadSpeed) }
    var downloadFormatted: String { ByteFormatter.formatSpeed(downloadSpeed) }
}

struct EnergyHog {
    let name: String
    let cpuPercent: Double
}

struct BatteryMetrics {
    var chargePercent: Int = 0
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var cycleCount: Int = 0
    var health: Double = 0
    var timeRemaining: Int? = nil
    var isOptimizedHolding: Bool = false
    var energyHogs: [EnergyHog] = []

    var statusText: String {
        if isOptimizedHolding {
            return "Holding at 80%"
        } else if isCharging {
            return "Charging"
        } else if isPluggedIn && chargePercent == 100 {
            return "Fully charged"
        } else if let minutes = timeRemaining {
            let h = minutes / 60
            let m = minutes % 60
            return "\(h):\(String(format: "%02d", m)) remaining"
        } else {
            return "On battery"
        }
    }

}
