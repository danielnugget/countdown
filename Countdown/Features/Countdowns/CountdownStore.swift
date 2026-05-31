import CountdownShared
import Foundation
import Observation
import SwiftData
import WidgetKit

@MainActor
@Observable
final class CountdownStore {
    var snapshots: [CountdownSnapshot] = []
    var selectedID: UUID?
    var searchText = ""
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
        guard let selectedID else {
            return snapshots.first
        }
        return snapshots.first { $0.id == selectedID } ?? snapshots.first
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            snapshots = try await actor.snapshots(searchText: searchText)
            if let selectedID, snapshots.contains(where: { $0.id == selectedID }) {
                self.selectedID = selectedID
            } else {
                selectedID = snapshots.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectCountdown(_ id: UUID) {
        selectedID = id
    }

    func consumePendingHandoff() {
        if let id = CountdownHandoffStore.consumeOpenCountdownID() {
            selectedID = id
        }
    }

    func createCountdown(
        title: String,
        targetDate: Date,
        colorName: String,
        symbolName: String
    ) async {
        await mutate {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            let snapshot = try await actor.createCountdown(
                title: title,
                targetDate: targetDate,
                colorName: colorName,
                symbolName: symbolName
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
        symbolName: String
    ) async {
        await mutate {
            let actor = CountdownDataActor(modelContainer: modelContainer)
            let updated = try await actor.updateCountdown(
                id: snapshot.id,
                title: title,
                targetDate: targetDate,
                colorName: colorName,
                symbolName: symbolName
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

    func setMenuBarExtraVisibility(_ isVisible: Bool) {
        var updated = settings
        updated.showsMenuBarExtra = isVisible
        updateSettings(updated)
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
}
