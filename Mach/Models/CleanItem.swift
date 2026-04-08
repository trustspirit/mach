import Foundation

enum CleanCategory: String, CaseIterable {
    case system
    case developer
}

struct CleanItem: Identifiable {
    let id: String
    let name: String
    let category: CleanCategory
    var sizeBytes: UInt64?
    let requiresRoot: Bool

    var formattedSize: String {
        guard let bytes = sizeBytes else { return "\u{2014}" }
        return Self.formatBytes(bytes)
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1_024 {
            return "\(bytes) B"
        } else if b < 1_048_576 {
            return String(format: "%.1f KB", b / 1_024)
        } else if b < 1_073_741_824 {
            return String(format: "%.1f MB", b / 1_048_576)
        } else {
            return String(format: "%.1f GB", b / 1_073_741_824)
        }
    }
}

struct CleanResult {
    let itemId: String
    let freedBytes: UInt64
    let success: Bool
    let error: String?

    var formattedFreed: String {
        CleanItem.formatBytes(freedBytes)
    }
}
