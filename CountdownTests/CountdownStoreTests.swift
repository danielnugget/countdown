import XCTest
import SwiftUI
import CoreData
@testable import Countdown
import CountdownShared

@MainActor
final class CountdownStoreTests: XCTestCase {
    func testSearchAndSortUpdateWithoutAnotherDatabaseRead() async throws {
        let (store, actor) = try makeStore()
        let now = Date()
        let beta = try await actor.createCountdown(title: "Beta", targetDate: now.addingTimeInterval(600))
        let alpha = try await actor.createCountdown(title: "Alpha", targetDate: now.addingTimeInterval(1_200))
        defer { cleanupMetadata([beta, alpha]) }
        await store.refresh()

        store.sort = .title
        XCTAssertEqual(store.snapshots.map(\.title), ["Alpha", "Beta"])
        store.searchText = "  beta  "
        XCTAssertEqual(store.snapshots.map(\.id), [beta.id])
        store.searchText = ""
        XCTAssertEqual(store.snapshots.count, 2)
    }

    func testOpeningCountdownOutsideCurrentFiltersShowsItsDetail() async throws {
        let (store, actor) = try makeStore()
        let snapshot = try await actor.createCountdown(
            title: "Trip", targetDate: Date().addingTimeInterval(600), collectionName: "Travel"
        )
        defer { cleanupMetadata([snapshot]) }
        await store.refresh()
        store.setCollectionFilter("Work")
        store.searchText = "unrelated"
        store.selectCountdown(snapshot.id)
        await store.refresh()

        XCTAssertEqual(store.selectedSnapshot?.id, snapshot.id)
        XCTAssertFalse(store.isShowingOverview)
        XCTAssertEqual(store.snapshots.map(\.id), [snapshot.id])
    }

    func testFailedCreationKeepsCurrentNavigation() async throws {
        let (store, _) = try makeStore()
        await store.refresh()
        await store.createCountdown(
            title: " ", targetDate: Date().addingTimeInterval(600),
            colorName: "blue", symbolName: "calendar", tags: [], collectionName: nil
        )

        XCTAssertTrue(store.isShowingOverview)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.allSnapshots.isEmpty)
    }

    func testDeadlineUpdatesCountsFiltersAndSelectionWithoutDatabaseRefresh() async throws {
        let (store, actor) = try makeStore()
        let now = Date()
        let snapshot = try await actor.createCountdown(title: "Due", targetDate: now.addingTimeInterval(60))
        defer { cleanupMetadata([snapshot]) }
        await store.refresh()
        store.setStatusFilter(.upcoming)
        store.selectCountdown(snapshot.id)
        XCTAssertEqual(store.upcomingCount, 1)

        store.advanceClock(now: now.addingTimeInterval(61))
        XCTAssertEqual(store.finishedCount, 1)
        XCTAssertEqual(store.upcomingCount, 0)
        XCTAssertTrue(store.snapshots.isEmpty)
        XCTAssertNil(store.selectedID)
        XCTAssertNil(store.nextExpirationDate)
        store.setStatusFilter(.finished)
        XCTAssertEqual(store.snapshots.map(\.id), [snapshot.id])
    }

    func testNotificationToggleReconcilesAllCountdownsWhileFiltered() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let scheduler = RecordingNotificationScheduler()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "CountdownTests.\(UUID())"))
        let settingsStore = CountdownSettingsStore(defaults: defaults, key: "settings")
        defer { defaults.removeObject(forKey: "settings") }
        let store = CountdownStore(
            modelContainer: container, settingsStore: settingsStore,
            notificationScheduler: scheduler, initialSettings: CountdownAppSettings(notificationsEnabled: false)
        )
        let first = try await actor.createCountdown(title: "First", targetDate: Date().addingTimeInterval(600))
        let second = try await actor.createCountdown(title: "Second", targetDate: Date().addingTimeInterval(1_200))
        defer { cleanupMetadata([first, second]) }
        await store.refresh()
        store.searchText = "no matches"
        await store.updateSettings(CountdownAppSettings(notificationsEnabled: true))
        XCTAssertEqual(Set(scheduler.scheduled.map(\.id)), Set([first.id, second.id]))
        XCTAssertTrue(settingsStore.load().notificationsEnabled)

        await store.updateSettings(CountdownAppSettings(notificationsEnabled: false))
        XCTAssertEqual(Set(scheduler.cancelled.compactMap { $0 }), Set([first.notificationIdentifier, second.notificationIdentifier].compactMap { $0 }))
        XCTAssertFalse(settingsStore.load().notificationsEnabled)
    }

    func testClockChangeReschedulesCountdownsOutsideCurrentFilter() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let scheduler = RecordingNotificationScheduler()
        let store = CountdownStore(modelContainer: container, notificationScheduler: scheduler)
        let snapshot = try await actor.createCountdown(title: "Hidden", targetDate: Date().addingTimeInterval(600))
        defer { cleanupMetadata([snapshot]) }
        await store.refresh()
        store.searchText = "no matches"
        await store.handleSystemTimeChange()
        XCTAssertEqual(scheduler.scheduled.map(\.id), [snapshot.id])
    }

    func testUpdatingCollectionKeepsUpdatedCountdownSelected() async throws {
        let (store, actor) = try makeStore()
        let snapshot = try await actor.createCountdown(
            title: "Trip", targetDate: Date().addingTimeInterval(600), collectionName: "Travel"
        )
        defer { cleanupMetadata([snapshot]) }
        await store.refresh()
        store.setCollectionFilter("Travel")
        store.selectCountdown(snapshot.id)
        let saved = await store.updateCountdown(
            snapshot, title: "Trip", targetDate: snapshot.targetDate, colorName: "blue",
            symbolName: "timer", tags: [], collectionName: "Personal"
        )
        XCTAssertTrue(saved)
        XCTAssertEqual(store.selectedSnapshot?.collectionName, "Personal")
        XCTAssertEqual(store.selectedSnapshot?.symbolName, "timer")
    }

    func testLiveScheduleStopsForInactiveAndExpiredCountdowns() {
        let now = Date()
        let inactive = CountdownTimelineSchedule(deadline: nil)
        XCTAssertEqual(Array(inactive.entries(from: now, mode: .normal).prefix(60)), [now])
        let running = CountdownTimelineSchedule(deadline: now.addingTimeInterval(2.5))
        let dates = Array(running.entries(from: now, mode: .normal).prefix(60))
        XCTAssertEqual(dates.count, 4)
        XCTAssertGreaterThanOrEqual(dates.last ?? now, now.addingTimeInterval(2.5))
    }

    func testExternalDataAndCalendarEventsHaveSeparateCallbacksAndCleanUp() {
        let center = NotificationCenter()
        var dataChanges = 0
        var timeChanges = 0
        var observer: CountdownSystemEventObserver? = CountdownSystemEventObserver(
            notificationCenter: center,
            onEvent: { timeChanges += 1 },
            onDataChange: { dataChanges += 1 }
        )
        XCTAssertNotNil(observer)
        center.post(name: .NSPersistentStoreRemoteChange, object: nil)
        XCTAssertEqual(dataChanges, 1)
        XCTAssertEqual(timeChanges, 0)
        center.post(name: .NSCalendarDayChanged, object: nil)
        XCTAssertEqual(timeChanges, 1)
        observer = nil
        center.post(name: .NSPersistentStoreRemoteChange, object: nil)
        XCTAssertEqual(dataChanges, 1)
    }

    private func makeStore() throws -> (CountdownStore, CountdownDataActor) {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        return (
            CountdownStore(
                modelContainer: container,
                notificationScheduler: CountdownNotificationScheduler(),
                initialSettings: CountdownAppSettings(notificationsEnabled: false)
            ),
            CountdownDataActor(modelContainer: container)
        )
    }

    private func cleanupMetadata(_ snapshots: [CountdownSnapshot]) {
        for snapshot in snapshots {
            CountdownTagStore().removeTags(for: snapshot.id)
            CountdownCollectionStore().removeCollection(for: snapshot.id)
        }
    }
}

@MainActor
private final class RecordingNotificationScheduler: CountdownNotificationScheduling {
    var scheduled: [CountdownSnapshot] = []
    var cancelled: [String?] = []

    func schedule(snapshot: CountdownSnapshot) async { scheduled.append(snapshot) }
    func cancel(identifier: String?) async { cancelled.append(identifier) }
}
