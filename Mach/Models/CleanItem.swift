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
    var isAvailable: Bool = true

    var formattedSize: String {
        guard let bytes = sizeBytes else { return "\u{2014}" }
        return ByteFormatter.format(bytes)
    }
}

struct CleanResult {
    let itemId: String
    let freedBytes: UInt64
    let success: Bool
    let error: String?

    var formattedFreed: String {
        ByteFormatter.format(freedBytes)
    }
}
