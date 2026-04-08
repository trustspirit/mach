import Foundation

struct TempCleaner: Cleaner {
    let id = "temp-files"
    let name = "Temp Files"
    let category: CleanCategory = .system
    let requiresRoot = false

    private var tempPath: String {
        NSTemporaryDirectory()
    }

    func scanSize() async -> UInt64 {
        staleFileSize(at: tempPath)
    }

    func clean() async throws -> CleanResult {
        let sizeBefore = staleFileSize(at: tempPath)
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600) // 7 days old
        guard let contents = try? fm.contentsOfDirectory(atPath: tempPath) else {
            return CleanResult(itemId: id, freedBytes: 0, success: true, error: nil)
        }
        for item in contents {
            let fullPath = tempPath + "/" + item
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                  let modified = attrs[.modificationDate] as? Date,
                  modified < cutoff else { continue }
            try? fm.removeItem(atPath: fullPath)
        }
        let sizeAfter = staleFileSize(at: tempPath)
        let freed = sizeBefore > sizeAfter ? sizeBefore - sizeAfter : 0
        return CleanResult(itemId: id, freedBytes: freed, success: true, error: nil)
    }

    /// Only count files older than 7 days
    private func staleFileSize(at path: String) -> UInt64 {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsPackageDescendants]) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isSymbolicLink != true,
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate, modified < cutoff,
                  let size = values.totalFileAllocatedSize else { continue }
            total += UInt64(size)
        }
        return total
    }
}
