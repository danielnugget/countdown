import CountdownShared
import Foundation
import Observation
import SwiftData
import WidgetKit

@MainActor
@Observable
final class CountdownStore {
    private(set) var allSnapshots: [CountdownSnapshot] = []
    private(set) var snapshots: [CountdownSnapshot] = []
    var selectedID: UUID?
    var isShowingOverview = true
    var searchText: String = "" {
        didSet { if searchText != oldValue { applyFilters() } }
    }
    var statusFilter: CountdownStatusFilter = .all {
        didSet { if statusFilter != oldValue { applyFilters() } }
    }
    var selectedTags: [String] = [] {
        didSet { if selectedTags != oldValue { applyFilters() } }
    }
    var selectedCollectionName: String? = nil {
        didSet { if selectedCollectionName != oldValue { applyFilters() } }
    }
    var sort: CountdownSort = .targetDate {
        didSet {
            if sort != oldValue {
                updateSortedSnapshots()
                applyFilters()
            }
        }
    }
    var isLoading = false
    private(set) var isSaving = false
    var errorMessage: String?
    var settings: CountdownAppSettings

    private let modelContainer: ModelContainer
    private let settingsStore: CountdownSettingsStore
    private let notificationScheduler: any CountdownNotificationScheduling
    @ObservationIgnored private var refreshRevision = 0
    @ObservationIgnored private var sortedSnapshots: [CountdownSnapshot] = []
    private(set) var availableTags: [String] = []
    private(set) var availableCollections: [String] = []
    private(set) var upcomingCount = 0
    private(set) var finishedCount = 0
    private var tagCounts: [String: Int] = [:]
    private var collectionCounts: [String: Int] = [:]

    init(
        modelContainer: ModelContainer,
        settingsStore: CountdownSettingsStore = CountdownSettingsStore(),
        notificationScheduler: any CountdownNotificationScheduling,
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

    var nextExpirationDate: Date? {
        allSnapshots.lazy.filter { $0.status == .running }.map(\.targetDate).min()
    }

    func count(for tag: String) -> Int {
        tagCounts[CountdownTagNormalizer.key(for: tag), default: 0]
    }

    func count(forCollection collectionName: String) -> Int {
        collectionCounts[CountdownCollectionNormalizer.key(for: collectionName), default: 0]
    }

    // MARK: - Loading and local queries

    func refresh() async {
        refreshRevision += 1
        let revision = refreshRevision
        isLoading = true
        defer { if revision == refreshRevision { isLoading = false } }

        do {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            let loaded = try await actor.snapshots()
            guard revision == refreshRevision else { return }
            replaceSnapshots(loaded)
        } catch {
            if revision == refreshRevision { errorMessage = error.localizedDescription }
        }
    }

    /// Refresh status-dependent summaries at a deadline without reading or writing SwiftData.
    func advanceClock(now: Date = Date()) {
        replaceSnapshots(allSnapshots.map { $0.recalculated(now: now) })
    }

    func selectCountdown(_ id: UUID) {
        isShowingOverview = false
        if !snapshots.contains(where: { $0.id == id }) {
            clearFilters()
        }
        selectedID = id
        if !allSnapshots.contains(where: { $0.id == id }) {
            // A URL or intent may refer to a countdown created by another process.
            Task { await refresh() }
        }
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
            selectCountdown(id)
        }
    }

    // MARK: - Mutations

    @discardableResult
    func createCountdown(
        title: String,
        targetDate: Date,
        colorName: String,
        symbolName: String,
        tags: [String],
        collectionName: String?
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        return await mutate {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            let snapshot = try await actor.createCountdown(
                title: title,
                targetDate: targetDate,
                colorName: colorName,
                symbolName: symbolName,
                tags: tags,
                collectionName: collectionName
            )
            isShowingOverview = false
            searchText = ""
            statusFilter = .all
            selectedTags = []
            selectedCollectionName = CountdownCollectionNormalizer.normalize(collectionName)
            selectedID = snapshot.id
            await scheduleNotification(for: snapshot)
        }
    }

    @discardableResult
    func updateCountdown(
        _ snapshot: CountdownSnapshot,
        title: String,
        targetDate: Date,
        colorName: String,
        symbolName: String,
        tags: [String],
        collectionName: String?
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        return await mutate {
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
            if CountdownSnapshotQuery.apply(
                to: [updated], searchText: searchText, sort: sort, filter: activeFilter
            ).isEmpty { clearFilters() }
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
            let updated = try await actor.markExpiredCountdowns()
            replaceSnapshots(updated)
            await reconcileNotifications()
        }
    }

    func updateSettings(_ settings: CountdownAppSettings) async {
        let notificationsChanged = self.settings.notificationsEnabled != settings.notificationsEnabled
        self.settings = settings
        settingsStore.save(settings)
        WidgetCenter.shared.reloadTimelines(ofKind: CountdownConstants.widgetKind)
        if notificationsChanged { await reconcileNotifications() }
    }

    func reconcileNotifications() async {
        for snapshot in allSnapshots {
            guard !Task.isCancelled else { return }
            await scheduleNotification(for: snapshot.recalculated())
        }
    }

    @discardableResult
    private func mutate(_ operation: () async throws -> Void) async -> Bool {
        do {
            errorMessage = nil
            try await operation()
            WidgetCenter.shared.reloadTimelines(ofKind: CountdownConstants.widgetKind)
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func scheduleNotification(for snapshot: CountdownSnapshot) async {
        guard settings.notificationsEnabled else {
            await notificationScheduler.cancel(identifier: snapshot.notificationIdentifier)
            return
        }

        await notificationScheduler.schedule(snapshot: snapshot)
        // Preferences can change while the authorization dialog or scheduler is awaiting.
        if !settings.notificationsEnabled {
            await notificationScheduler.cancel(identifier: snapshot.notificationIdentifier)
        }
    }

    // MARK: - Derived state

    private func applyFilters() {
        snapshots = CountdownSnapshotQuery.apply(
            to: sortedSnapshots, searchText: searchText, sort: nil, filter: activeFilter
        )
        if let selectedID, !snapshots.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        }
    }

    private func replaceSnapshots(_ loaded: [CountdownSnapshot]) {
        allSnapshots = loaded
        updateSortedSnapshots()
        availableTags = CountdownTagNormalizer.normalize(loaded.flatMap(\.tags))
        availableCollections = CountdownCollectionNormalizer.normalize(loaded.compactMap(\.collectionName))
        finishedCount = loaded.count { $0.status == .expired }
        upcomingCount = loaded.count - finishedCount
        var tags: [String: Int] = [:]
        var collections: [String: Int] = [:]
        for snapshot in loaded {
            for tag in snapshot.tags { tags[CountdownTagNormalizer.key(for: tag), default: 0] += 1 }
            if let name = snapshot.collectionName {
                collections[CountdownCollectionNormalizer.key(for: name), default: 0] += 1
            }
        }
        tagCounts = tags
        collectionCounts = collections
        applyFilters()
    }

    private func updateSortedSnapshots() {
        sortedSnapshots = CountdownSnapshotQuery.apply(to: allSnapshots, sort: sort)
    }
}
