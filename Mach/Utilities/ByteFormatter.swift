import Foundation

enum ByteFormatter {
    static func format(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1_024 { return "\(bytes) B" }
        if b < 1_048_576 { return String(format: "%.1f KB", b / 1_024) }
        if b < 1_073_741_824 { return String(format: "%.1f MB", b / 1_048_576) }
        return String(format: "%.1f GB", b / 1_073_741_824)
    }

    static func formatSpeed(_ bytesPerSec: UInt64) -> String {
        let b = Double(bytesPerSec)
        if b < 1_024 { return "\(bytesPerSec) B/s" }
        if b < 1_048_576 { return String(format: "%.1f KB/s", b / 1_024) }
        if b < 1_073_741_824 { return String(format: "%.1f MB/s", b / 1_048_576) }
        return String(format: "%.1f GB/s", b / 1_073_741_824)
    }

    static func formatCompact(_ bytesPerSec: UInt64) -> String {
        let b = Double(bytesPerSec)
        if b < 1_024 { return "0 K" }
        if b < 1_048_576 { return String(format: "%.0fK", b / 1_024) }
        if b < 1_073_741_824 { return String(format: "%.1fM", b / 1_048_576) }
        return String(format: "%.1fG", b / 1_073_741_824)
    }
}
