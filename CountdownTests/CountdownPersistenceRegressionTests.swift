import XCTest
import SwiftData
import CountdownShared

final class CountdownPersistenceRegressionTests: XCTestCase {
    func testDeleteRemovesModelAndMetadataAcrossActors() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let writer = CountdownDataActor(modelContainer: container)
        let snapshot = try await writer.createCountdown(
            title: "Delete test", targetDate: Date().addingTimeInterval(600),
            tags: ["QA"], collectionName: "Tests"
        )
        try await writer.deleteCountdown(id: snapshot.id)
        let reader = CountdownDataActor(modelContainer: container)
        let remaining = try await reader.snapshots()
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertTrue(CountdownTagStore().tags(for: snapshot.id).isEmpty)
        XCTAssertNil(CountdownCollectionStore().collectionName(for: snapshot.id))
        do {
            _ = try await reader.snapshot(id: snapshot.id)
            XCTFail("Deleted countdown should not be found")
        } catch CountdownError.countdownNotFound { }
    }

    func testInvalidInputDoesNotPersistCountdowns() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let now = Date()
        do {
            _ = try await actor.createCountdown(title: "  ", targetDate: now.addingTimeInterval(600), now: now)
            XCTFail("Blank titles must be rejected")
        } catch CountdownError.invalidTitle { }
        do {
            _ = try await actor.createCountdown(title: "Past", targetDate: now, now: now)
            XCTFail("A target at or before now must be rejected")
        } catch CountdownError.invalidTargetDate { }
        let remaining = try await actor.snapshots()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testExpirationIsIdempotentAndLeavesPausedCountdownsAlone() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let context = ModelContext(container)
        let running = CountdownItem(title: "Due", createdAt: now, targetDate: now.addingTimeInterval(60))
        let paused = CountdownItem(title: "Paused", createdAt: now, targetDate: now.addingTimeInterval(60), pausedRemainingSeconds: 30)
        context.insert(running)
        context.insert(paused)
        try context.save()
        let actor = CountdownDataActor(modelContainer: container)
        let first = try await actor.markExpiredCountdowns(now: now.addingTimeInterval(61))
        XCTAssertEqual(first.first { $0.title == "Due" }?.status, .expired)
        XCTAssertEqual(first.first { $0.title == "Paused" }?.status, .paused)
        let second = try await actor.markExpiredCountdowns(now: now.addingTimeInterval(120))
        XCTAssertEqual(second.first { $0.title == "Due" }?.completedAt, now.addingTimeInterval(61))
        XCTAssertNil(second.first { $0.title == "Paused" }?.completedAt)
    }

    func testMetadataRoundTripAndEmptyWrites() throws {
        let suite = "CountdownMetadataTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let tags = CountdownTagStore(defaults: defaults, key: "tags")
        let collections = CountdownCollectionStore(defaults: defaults, key: "collections")
        let id = UUID()
        tags.save([], for: id)
        collections.save(nil, for: id)
        XCTAssertNil(defaults.data(forKey: "tags"))
        XCTAssertNil(defaults.data(forKey: "collections"))
        tags.save([" QA ", "qa"], for: id)
        collections.save(" Tests ", for: id)
        XCTAssertEqual(tags.tags(for: id), ["QA"])
        XCTAssertEqual(collections.collectionName(for: id), "Tests")
        tags.removeTags(for: id)
        collections.removeCollection(for: id)
        XCTAssertTrue(tags.loadAll().isEmpty)
        XCTAssertTrue(collections.loadAll().isEmpty)
    }
}
