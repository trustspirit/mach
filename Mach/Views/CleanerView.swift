import SwiftUI

struct CleanerView: View {
    var onBack: () -> Void
    @StateObject private var cleanerManager = CleanerManager()
    @State private var hasScanned = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Quick Clean", systemImage: "bolt.fill").font(.headline)
                        Text(quickCleanEstimate).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Run") {
                        Task { await cleanerManager.quickClean() }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(!cleanerManager.inProgress.isEmpty)
                }.padding(12).background(.quaternary.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))

                Divider()
                ForEach(cleanerManager.items.filter { $0.category == .system }) { item in
                    cleanerRow(item: item)
                }
                Divider()
                Text("Developer Tools").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(cleanerManager.items.filter { $0.category == .developer }) { item in
                    cleanerRow(item: item)
                }
            }.padding(10)
        }.task {
            if !hasScanned {
                hasScanned = true
                await cleanerManager.scanAll()
            }
        }
    }

    private var quickCleanEstimate: String {
        let total = cleanerManager.items
            .filter { cleanerManager.quickCleanItemIds.contains($0.id) }
            .compactMap(\.sizeBytes)
            .reduce(UInt64(0), +)
        return total > 0 ? "Est. recovery: ~\(CleanItem.formatBytes(total))" : "Scanning..."
    }

    @ViewBuilder
    private func cleanerRow(item: CleanItem) -> some View {
        let available = cleanerManager.isAvailable(id: item.id)
        let isRunning = cleanerManager.inProgress.contains(item.id)
        let result = cleanerManager.results[item.id]
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.callout).foregroundStyle(available ? .primary : .secondary)
                if !available {
                    Text("Not installed").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isRunning {
                ProgressView().controlSize(.small)
            } else if let result = result {
                if result.success {
                    Label(
                        result.freedBytes > 0 ? result.formattedFreed + " freed" : "Done",
                        systemImage: "checkmark.circle.fill"
                    ).font(.caption).foregroundStyle(.green)
                } else {
                    Label("Failed", systemImage: "xmark.circle.fill").font(.caption).foregroundStyle(.red)
                }
            } else {
                Text(item.formattedSize).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                Button(item.id == "dns-cache" ? "Flush" : item.id == "memory" ? "Purge" : "Clean") {
                    Task { await cleanerManager.clean(id: item.id) }
                }
                .buttonStyle(.bordered).controlSize(.mini).disabled(!available)
            }
        }.padding(.vertical, 4)
    }
}
