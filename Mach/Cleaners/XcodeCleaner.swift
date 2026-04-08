import Foundation

struct XcodeCleaner: Cleaner {
    let id = "xcode-derived"
    let name = "Xcode DerivedData"
    let category: CleanCategory = .developer
    let requiresRoot = false

    private var derivedDataPath: String {
        NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
    }

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: derivedDataPath)
    }

    func scanSize() async -> UInt64 {
        directorySize(at: derivedDataPath)
    }

    func clean() async throws -> CleanResult {
        let sizeBefore = directorySize(at: derivedDataPath)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataPath) else {
            return CleanResult(itemId: id, freedBytes: 0, success: true, error: nil)
        }
        for item in contents {
            let fullPath = derivedDataPath + "/" + item
            try? fm.removeItem(atPath: fullPath)
        }
        let sizeAfter = directorySize(at: derivedDataPath)
        let freed = sizeBefore > sizeAfter ? sizeBefore - sizeAfter : 0
        return CleanResult(itemId: id, freedBytes: freed, success: true, error: nil)
    }
}
