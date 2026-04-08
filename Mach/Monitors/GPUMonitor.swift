import Foundation
import IOKit

final class GPUMonitor: ObservableObject {
    @Published var metrics = GPUMetrics()
    @Published var history: [Double] = []
    private let maxHistory = 60

    func update() {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any] else { return }

        if let perfStats = dict["PerformanceStatistics"] as? [String: Any] {
            if let utilization = perfStats["Device Utilization %"] as? Int {
                metrics.usage = Double(utilization)
            } else if let gpuActivity = perfStats["GPU Activity(%)"] as? Int {
                metrics.usage = Double(gpuActivity)
            }
            if let vramUsed = perfStats["VRAM Used"] as? UInt64 { metrics.vramUsed = vramUsed }
            else if let vramUsed = perfStats["vramUsedBytes"] as? UInt64 { metrics.vramUsed = vramUsed }
            if let vramTotal = perfStats["VRAM Total"] as? UInt64 { metrics.vramTotal = vramTotal }
        }
        history.append(metrics.usage)
        if history.count > maxHistory { history.removeFirst() }
    }
}
