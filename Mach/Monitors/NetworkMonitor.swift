import Foundation
import Darwin

final class NetworkMonitor: ObservableObject {
    @Published var metrics = NetworkMetrics()
    @Published var downloadHistory: [Double] = []
    @Published var uploadHistory: [Double] = []
    private let maxHistory = 60
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTime: Date?

    func update() {
        var totalIn: UInt64 = 0, totalOut: UInt64 = 0
        var primaryInterface = ""
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            let name = String(cString: addr.pointee.ifa_name)
            if addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let data = unsafeBitCast(addr.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                totalIn += UInt64(data.pointee.ifi_ibytes)
                totalOut += UInt64(data.pointee.ifi_obytes)
                if name.hasPrefix("en") && (primaryInterface.isEmpty || name == "en0") {
                    primaryInterface = name
                }
            }
            cursor = addr.pointee.ifa_next
        }
        let now = Date()
        if let prevTime = previousTime {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                let deltaIn = totalIn >= previousBytesIn ? totalIn - previousBytesIn : 0
                let deltaOut = totalOut >= previousBytesOut ? totalOut - previousBytesOut : 0
                metrics.uploadSpeed = UInt64(Double(deltaOut) / elapsed)
                metrics.downloadSpeed = UInt64(Double(deltaIn) / elapsed)
            }
        }
        metrics.interfaceName = primaryInterface
        previousBytesIn = totalIn; previousBytesOut = totalOut; previousTime = now
        downloadHistory.append(Double(metrics.downloadSpeed))
        if downloadHistory.count > maxHistory { downloadHistory.removeFirst() }
        uploadHistory.append(Double(metrics.uploadSpeed))
        if uploadHistory.count > maxHistory { uploadHistory.removeFirst() }
    }
}
