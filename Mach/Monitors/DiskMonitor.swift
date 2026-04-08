import Foundation
import IOKit

final class DiskMonitor: ObservableObject {
    @Published var metrics = DiskMetrics()
    @Published var history: [Double] = []
    private let maxHistory = 60
    private var previousRead: UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousTime: Date?

    func update() {
        updateSpace()
        updateIOSpeed()
        history.append(metrics.usagePercent)
        if history.count > maxHistory { history.removeFirst() }
    }

    private func updateSpace() {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return }
        let total = attrs[.systemSize] as? UInt64 ?? 0
        let free = attrs[.systemFreeSize] as? UInt64 ?? 0
        metrics.totalSpace = total
        metrics.usedSpace = total - free
    }

    private func updateIOSpeed() {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        var totalRead: UInt64 = 0, totalWrite: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = properties?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                totalRead += stats["Bytes (Read)"] as? UInt64 ?? 0
                totalWrite += stats["Bytes (Write)"] as? UInt64 ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        let now = Date()
        if let prevTime = previousTime {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                metrics.readSpeed = UInt64(Double(totalRead - previousRead) / elapsed)
                metrics.writeSpeed = UInt64(Double(totalWrite - previousWrite) / elapsed)
            }
        }
        previousRead = totalRead; previousWrite = totalWrite; previousTime = now
    }
}
