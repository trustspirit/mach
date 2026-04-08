import Foundation
import IOKit

final class GPUMonitor: ObservableObject {
    @Published var metrics = GPUMetrics()
    @Published var history: [Double] = []
    private let maxHistory = 60
    private var resolvedName: String?

    func update() {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS else {
            history.append(0)
            if history.count > maxHistory { history.removeFirst() }
            return
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            history.append(0)
            if history.count > maxHistory { history.removeFirst() }
            return
        }
        defer { IOObjectRelease(service) }

        // Resolve GPU name once
        if resolvedName == nil {
            if let nameEntry = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                if let data = nameEntry as? Data, let str = String(data: data, encoding: .utf8) {
                    resolvedName = str.trimmingCharacters(in: .controlCharacters)
                } else if let str = nameEntry as? String {
                    resolvedName = str
                }
            }
            // Fallback: check IOName
            if resolvedName == nil || resolvedName!.isEmpty {
                var nameBuffer = [CChar](repeating: 0, count: 128)
                if IORegistryEntryGetName(service, &nameBuffer) == KERN_SUCCESS {
                    let n = String(cString: nameBuffer)
                    if !n.isEmpty && n != "IOAccelerator" { resolvedName = n }
                }
            }
            if resolvedName == nil { resolvedName = "" }
        }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any] else { return }

        metrics.name = resolvedName ?? ""

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
