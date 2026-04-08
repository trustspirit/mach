import Foundation

struct CacheCleaner: Cleaner {
    let id = "system-cache"
    let name = "System Cache"
    let category: CleanCategory = .system
    let requiresRoot = false

    private var cachesPath: String {
        NSHomeDirectory() + "/Library/Caches"
    }

    func scanSize() async -> UInt64 {
        directorySize(at: cachesPath)
    }

    func clean() async throws -> CleanResult {
        let sizeBefore = directorySize(at: cachesPath)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: cachesPath) else {
            return CleanResult(itemId: id, freedBytes: 0, success: true, error: nil)
        }
        for item in contents {
            let fullPath = cachesPath + "/" + item
            try? fm.removeItem(atPath: fullPath)
        }
        let sizeAfter = directorySize(at: cachesPath)
        let freed = sizeBefore > sizeAfter ? sizeBefore - sizeAfter : 0
        return CleanResult(itemId: id, freedBytes: freed, success: true, error: nil)
    }
}
