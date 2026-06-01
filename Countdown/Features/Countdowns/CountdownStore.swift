import CountdownShared
import Foundation
import Observation
import SwiftData
import WidgetKit

@MainActor
@Observable
final class CountdownStore {
    var allSnapshots: [CountdownSnapshot] = []
    var snapshots: [CountdownSnapshot] = []
    var selectedID: UUID?
    var isShowingOverview = true
    var searchText = ""
    var statusFilter: CountdownStatusFilter = .all
    var selectedTags: [String] = []
    var selectedCollectionName: String?
    var sort: CountdownSort = .targetDate
    var isLoading = false
    var errorMessage: String?
    var settings: CountdownAppSettings

    private let modelContainer: ModelContainer
    private let settingsStore: CountdownSettingsStore
    private let notificationScheduler: CountdownNotificationScheduler

    init(
        modelContainer: ModelContainer,
        settingsStore: CountdownSettingsStore = CountdownSettingsStore(),
        notificationScheduler: CountdownNotificationScheduler,
        initialSettings: CountdownAppSettings = CountdownAppSettings(),
        initialError: String? = nil
    ) {
        self.modelContainer = modelContainer
        self.settingsStore = settingsStore
        self.notificationScheduler = notificationScheduler
        self.settings = initialSettings
        self.errorMessage = initialError
    }

    var selectedSnapshot: CountdownSnapshot? {
        guard let selectedID else { return nil }
        return allSnapshots.first { $0.id == selectedID }
    }

    var activeFilter: CountdownFilter {
        CountdownFilter(status: statusFilter, tags: selectedTags, collectionName: selectedCollectionName)
    }

    var availableTags: [String] {
        CountdownTagNormalizer.normalize(allSnapshots.flatMap(\.tags))
    }

    var availableCollections: [String] {
        CountdownCollectionNormalizer.normalize(allSnapshots.compactMap(\.collectionName))
    }

    var upcomingCount: Int {
        allSnapshots.filter { $0.status != .expired }.count
    }

    var finishedCount: Int {
        allSnapshots.filter { $0.status == .expired }.count
    }

    func count(for tag: String) -> Int {
        let key = CountdownTagNormalizer.key(for: tag)
        return allSnapshots.filter { snapshot in
            snapshot.tags.map(CountdownTagNormalizer.key(for:)).contains(key)
        }.count
    }

    func count(forCollection collectionName: String) -> Int {
        let key = CountdownCollectionNormalizer.key(for: collectionName)
        return allSnapshots.filter { snapshot in
            guard let collectionName = snapshot.collectionName else {
                return false
            }

            return CountdownCollectionNormalizer.key(for: collectionName) == key
        }.count
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            allSnapshots = try await actor.snapshots(sort: sort)
            snapshots = filteredSnapshots(from: allSnapshots)
            if let selectedID, snapshots.contains(where: { $0.id == selectedID }) {
                self.selectedID = selectedID
            } else {
                selectedID = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectCountdown(_ id: UUID) {
        isShowingOverview = false
        selectedID = id
    }

    func showDashboard() {
        isShowingOverview = true
        searchText = ""
        statusFilter = .all
        selectedTags = []
        selectedCollectionName = nil
        selectedID = nil
    }

    func setStatusFilter(_ filter: CountdownStatusFilter) {
        isShowingOverview = false
        statusFilter = filter
        selectedTags = []
        selectedID = nil
    }

    func setTagFilter(_ tag: String) {
        isShowingOverview = false
        statusFilter = .all
        selectedTags = CountdownTagNormalizer.normalize([tag])
        selectedID = nil
    }

    func setCollectionFilter(_ collectionName: String) {
        isShowingOverview = false
        searchText = ""
        statusFilter = .all
        selectedTags = []
        selectedCollectionName = CountdownCollectionNormalizer.normalize(collectionName)
        selectedID = nil
    }

    func clearFilters() {
        isShowingOverview = false
        searchText = ""
        statusFilter = .all
        selectedTags = []
        selectedCollectionName = nil
        selectedID = nil
    }

    func consumePendingHandoff() {
        if let id = CountdownHandoffStore.consumeOpenCountdownID() {
            isShowingOverview = false
            selectedID = id
        }
    }

    func createCountdown(
        title: String,
        targetDate: Date,
        colorName: String,
        symbolName: String,
        tags: [String],
        collectionName: String?
    ) async {
        await mutate {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            isShowingOverview = false
            searchText = ""
            statusFilter = .all
            selectedTags = []
            selectedCollectionName = CountdownCollectionNormalizer.normalize(collectionName)
            let snapshot = try await actor.createCountdown(
                title: title,
                targetDate: targetDate,
                colorName: colorName,
                symbolName: symbolName,
                tags: tags,
                collectionName: collectionName
            )
            selectedID = snapshot.id
            await scheduleNotification(for: snapshot)
        }
    }

    func updateCountdown(
        _ snapshot: CountdownSnapshot,
        title: String,
        targetDate: Date,
        colorName: String,
        symbolName: String,
        tags: [String],
        collectionName: String?
    ) async {
        await mutate {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            let updated = try await actor.updateCountdown(
                id: snapshot.id,
                title: title,
                targetDate: targetDate,
                colorName: colorName,
                symbolName: symbolName,
                tags: tags,
                collectionName: collectionName
            )
            selectedID = updated.id
            await scheduleNotification(for: updated)
        }
    }

    func delete(_ snapshot: CountdownSnapshot) async {
        await mutate {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            try await actor.deleteCountdown(id: snapshot.id)
            await notificationScheduler.cancel(identifier: snapshot.notificationIdentifier)
            selectedID = nil
        }
    }

    func handleSystemTimeChange() async {
        await mutate {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            _ = try await actor.markExpiredCountdowns()
            for snapshot in snapshots where snapshot.status == .running {
                await scheduleNotification(for: snapshot)
            }
        }
    }

    func updateSettings(_ settings: CountdownAppSettings) {
        self.settings = settings
        settingsStore.save(settings)
        WidgetCenter.shared.reloadTimelines(ofKind: CountdownConstants.widgetKind)
    }

    private func mutate(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            WidgetCenter.shared.reloadTimelines(ofKind: CountdownConstants.widgetKind)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleNotification(for snapshot: CountdownSnapshot) async {
        guard settings.notificationsEnabled else {
            await notificationScheduler.cancel(identifier: snapshot.notificationIdentifier)
            return
        }

        await notificationScheduler.schedule(snapshot: snapshot)
    }

    private func filteredSnapshots(from snapshots: [CountdownSnapshot]) -> [CountdownSnapshot] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedTagKeys = Set(activeFilter.tags.map(CountdownTagNormalizer.key(for:)))
        let selectedCollectionKey = activeFilter.collectionName.map(CountdownCollectionNormalizer.key(for:))

        return snapshots
            .filter { snapshot in
                normalizedSearch.isEmpty
                    || snapshot.title.localizedCaseInsensitiveContains(normalizedSearch)
                    || snapshot.tags.contains { $0.localizedCaseInsensitiveContains(normalizedSearch) }
                    || snapshot.collectionName?.localizedCaseInsensitiveContains(normalizedSearch) == true
            }
            .filter { snapshot in
                activeFilter.status.includes(snapshot.status)
            }
            .filter { snapshot in
                guard let selectedCollectionKey else {
                    return true
                }

                guard let collectionName = snapshot.collectionName else {
                    return false
                }

                return CountdownCollectionNormalizer.key(for: collectionName) == selectedCollectionKey
            }
            .filter { snapshot in
                guard !selectedTagKeys.isEmpty else {
                    return true
                }

                let snapshotTagKeys = Set(snapshot.tags.map(CountdownTagNormalizer.key(for:)))
                return selectedTagKeys.isSubset(of: snapshotTagKeys)
            }
    }
}
