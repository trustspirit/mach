import Foundation

struct LogCleaner: Cleaner {
    let id = "app-logs"
    let name = "App Logs"
    let category: CleanCategory = .system
    let requiresRoot = false

    private var logsPath: String {
        NSHomeDirectory() + "/Library/Logs"
    }

    func scanSize() async -> UInt64 {
        directorySize(at: logsPath)
    }

    func clean() async throws -> CleanResult {
        let sizeBefore = directorySize(at: logsPath)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: logsPath) else {
            return CleanResult(itemId: id, freedBytes: 0, success: true, error: nil)
        }
        for item in contents {
            let fullPath = logsPath + "/" + item
            try? fm.removeItem(atPath: fullPath)
        }
        let sizeAfter = directorySize(at: logsPath)
        let freed = sizeBefore > sizeAfter ? sizeBefore - sizeAfter : 0
        return CleanResult(itemId: id, freedBytes: freed, success: true, error: nil)
    }
}
