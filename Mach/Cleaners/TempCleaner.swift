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
        directorySize(at: tempPath)
    }

    func clean() async throws -> CleanResult {
        let sizeBefore = directorySize(at: tempPath)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: tempPath) else {
            return CleanResult(itemId: id, freedBytes: 0, success: true, error: nil)
        }
        for item in contents {
            let fullPath = tempPath + "/" + item
            try? fm.removeItem(atPath: fullPath)
        }
        let sizeAfter = directorySize(at: tempPath)
        let freed = sizeBefore > sizeAfter ? sizeBefore - sizeAfter : 0
        return CleanResult(itemId: id, freedBytes: freed, success: true, error: nil)
    }
}
