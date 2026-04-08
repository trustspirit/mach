import Foundation

protocol Cleaner {
    var id: String { get }
    var name: String { get }
    var category: CleanCategory { get }
    var requiresRoot: Bool { get }
    var isAvailable: Bool { get }
    func scanSize() async -> UInt64
    func clean() async throws -> CleanResult
}

extension Cleaner {
    var isAvailable: Bool { true }
}

func directorySize(at path: String) -> UInt64 {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
    var total: UInt64 = 0
    while let file = enumerator.nextObject() as? String {
        let fullPath = path + "/" + file
        if let attrs = try? fm.attributesOfItem(atPath: fullPath),
           let size = attrs[.size] as? UInt64 {
            total += size
        }
    }
    return total
}
