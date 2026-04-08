import Foundation

protocol Cleaner {
    var id: String { get }
    var name: String { get }
    var category: CleanCategory { get }
    var requiresRoot: Bool { get }
    var isAvailable: Bool { get }
    func checkAvailable() async -> Bool
    func scanSize() async -> UInt64
    func clean() async throws -> CleanResult
}

extension Cleaner {
    var isAvailable: Bool { true }
    func checkAvailable() async -> Bool { isAvailable }
}

func directorySize(at path: String) -> UInt64 {
    let url = URL(fileURLWithPath: path)
    let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
    guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: Array(keys),
        options: [.skipsPackageDescendants]
    ) else { return 0 }
    var total: UInt64 = 0
    for case let fileURL as URL in enumerator {
        guard let values = try? fileURL.resourceValues(forKeys: keys),
              values.isSymbolicLink != true,
              values.isRegularFile == true,
              let size = values.totalFileAllocatedSize else { continue }
        total += UInt64(size)
    }
    return total
}
