import Foundation

final class CleanerManager: ObservableObject {
    let cleaners: [any Cleaner]
    @Published var items: [CleanItem] = []
    @Published var results: [String: CleanResult] = [:]
    @Published var inProgress: Set<String> = []
    let quickCleanItemIds = ["system-cache", "app-logs", "temp-files", "memory"]

    init() {
        cleaners = [
            CacheCleaner(),
            LogCleaner(),
            TempCleaner(),
            DNSCleaner(),
            MemoryCleaner(),
            XcodeCleaner(),
            DockerCleaner(),
            BrewCleaner(),
            PackageCleaner.npm,
            PackageCleaner.yarn,
            PackageCleaner.pip
        ]
        items = cleaners.map {
            CleanItem(id: $0.id, name: $0.name, category: $0.category, sizeBytes: nil, requiresRoot: $0.requiresRoot)
        }
    }

    func scanAll() async {
        for (index, cleaner) in cleaners.enumerated() {
            guard cleaner.isAvailable else { continue }
            let size = await cleaner.scanSize()
            await MainActor.run { items[index].sizeBytes = size > 0 ? size : nil }
        }
    }

    func clean(id: String) async {
        guard let cleaner = cleaners.first(where: { $0.id == id }), cleaner.isAvailable else { return }
        await MainActor.run { inProgress.insert(id) }
        do {
            let result = try await cleaner.clean()
            await MainActor.run { results[id] = result; inProgress.remove(id) }
        } catch {
            await MainActor.run {
                results[id] = CleanResult(itemId: id, freedBytes: 0, success: false, error: error.localizedDescription)
                inProgress.remove(id)
            }
        }
    }

    func quickClean() async {
        for id in quickCleanItemIds {
            await clean(id: id)
        }
    }

    func isAvailable(id: String) -> Bool {
        cleaners.first(where: { $0.id == id })?.isAvailable ?? false
    }
}
