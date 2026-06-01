import XCTest
import SwiftData
@testable import CountdownShared

final class CountdownSharedTests: XCTestCase {
    func testCountdownFormattingUsesExpectedUnits() {
        XCTAssertEqual(CountdownFormatter.string(remainingSeconds: 65, precision: .compact), "1m 5s")
        XCTAssertEqual(CountdownFormatter.string(remainingSeconds: 3_661, precision: .automatic), "01:01:01")
        XCTAssertEqual(CountdownFormatter.string(remainingSeconds: 90_000, precision: .compact), "1d 1h")
        XCTAssertEqual(
            CountdownFormatter.string(remainingSeconds: 90_099, precision: .full),
            "1 day\n1 hour\n1 minute\n39 seconds"
        )
    }

    func testProgressClampsBetweenZeroAndOne() {
        XCTAssertEqual(CountdownCalculator.progress(remainingSeconds: 50, originalDurationSeconds: 100), 0.5)
        XCTAssertEqual(CountdownCalculator.progress(remainingSeconds: 150, originalDurationSeconds: 100), 0)
        XCTAssertEqual(CountdownCalculator.progress(remainingSeconds: -1, originalDurationSeconds: 100), 1)
    }

    func testStatusHandlesRunningPausedAndExpired() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        XCTAssertEqual(CountdownCalculator.status(
            targetDate: now.addingTimeInterval(60),
            pausedRemainingSeconds: nil,
            completedAt: nil,
            now: now
        ), .running)
        XCTAssertEqual(CountdownCalculator.status(
            targetDate: now.addingTimeInterval(60),
            pausedRemainingSeconds: 30,
            completedAt: nil,
            now: now
        ), .paused)
        XCTAssertEqual(CountdownCalculator.status(
            targetDate: now.addingTimeInterval(-1),
            pausedRemainingSeconds: nil,
            completedAt: nil,
            now: now
        ), .expired)
    }

    func testDateCountdownCreationUsesTargetDate() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let target = now.addingTimeInterval(300)

        let created = try await actor.createCountdown(
            title: "Launch",
            targetDate: target,
            now: now
        )

        XCTAssertEqual(created.title, "Launch")
        XCTAssertEqual(created.targetDate, target)
        XCTAssertNil(created.quickDurationSeconds)
        XCTAssertNil(created.pausedRemainingSeconds)
    }

    func testDateCountdownUpdateReplacesTargetDate() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let now = Date(timeIntervalSinceReferenceDate: 20_000)
        let target = now.addingTimeInterval(3_600)
        let newTarget = now.addingTimeInterval(7_200)

        let created = try await actor.createCountdown(title: "Launch", targetDate: target, now: now)
        let updated = try await actor.updateCountdown(
            id: created.id,
            title: "Updated Launch",
            targetDate: newTarget,
            colorName: "green",
            symbolName: "flag.checkered",
            now: now
        )

        XCTAssertEqual(updated.title, "Updated Launch")
        XCTAssertEqual(updated.targetDate, newTarget)
        XCTAssertNil(updated.quickDurationSeconds)
        XCTAssertNil(updated.pausedRemainingSeconds)
    }

    func testDateCountdownUpdatePersistsColorAndSymbol() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let now = Date(timeIntervalSinceReferenceDate: 30_000)
        let target = now.addingTimeInterval(3_600)
        let newTarget = now.addingTimeInterval(7_200)

        let created = try await actor.createCountdown(
            title: "Trip",
            targetDate: target,
            colorName: "blue",
            symbolName: "calendar",
            now: now
        )
        let updated = try await actor.updateCountdown(
            id: created.id,
            title: "Updated Trip",
            targetDate: newTarget,
            colorName: "orange",
            symbolName: "airplane",
            now: now
        )

        XCTAssertEqual(updated.colorName, "orange")
        XCTAssertEqual(updated.symbolName, "airplane")
    }

    func testTagNormalizationTrimsDeduplicatesAndSortsTags() {
        let tags = CountdownTagNormalizer.normalize([
            " Work ",
            "",
            "home",
            "work",
            "  Travel  ",
            "HOME"
        ])

        XCTAssertEqual(tags, ["home", "Travel", "Work"])
    }

    func testCreateAndUpdatePersistTags() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let now = Date(timeIntervalSinceReferenceDate: 50_000)
        let target = now.addingTimeInterval(3_600)

        let created = try await actor.createCountdown(
            title: "Conference",
            targetDate: target,
            tags: [" Work ", "travel", "work"],
            now: now
        )

        XCTAssertEqual(created.tags, ["travel", "Work"])

        let updated = try await actor.updateCountdown(
            id: created.id,
            title: "Conference",
            targetDate: target.addingTimeInterval(3_600),
            colorName: "blue",
            symbolName: "calendar",
            tags: ["Personal", " travel "],
            now: now
        )

        XCTAssertEqual(updated.tags, ["Personal", "travel"])
    }

    func testSnapshotsFilterBySelectedTags() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let now = Date(timeIntervalSinceReferenceDate: 60_000)

        _ = try await actor.createCountdown(
            title: "Launch",
            targetDate: now.addingTimeInterval(3_600),
            tags: ["Work", "Q1"],
            now: now
        )
        _ = try await actor.createCountdown(
            title: "Dinner",
            targetDate: now.addingTimeInterval(7_200),
            tags: ["Personal"],
            now: now
        )

        let work = try await actor.snapshots(now: now, filter: CountdownFilter(tags: ["work"]))
        XCTAssertEqual(work.map(\.title), ["Launch"])

        let workAndQuarter = try await actor.snapshots(now: now, filter: CountdownFilter(tags: ["q1", "WORK"]))
        XCTAssertEqual(workAndQuarter.map(\.title), ["Launch"])
    }

    func testSnapshotsCombineSearchStatusAndSort() async throws {
        let container = try CountdownContainerFactory.makeInMemoryContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let now = Date(timeIntervalSinceReferenceDate: 70_000)

        _ = try await actor.createCountdown(
            title: "Beta",
            targetDate: now.addingTimeInterval(900),
            tags: ["Home"],
            now: now
        )
        _ = try await actor.createCountdown(
            title: "Alpha",
            targetDate: now.addingTimeInterval(1_800),
            tags: ["Work"],
            now: now
        )

        let searched = try await actor.snapshots(
            now: now,
            searchText: "home",
            sort: .title,
            filter: CountdownFilter(status: .upcoming)
        )
        XCTAssertEqual(searched.map(\.title), ["Beta"])

        _ = try await actor.markExpiredCountdowns(now: now.addingTimeInterval(1_000))
        let finished = try await actor.snapshots(
            now: now.addingTimeInterval(1_000),
            filter: CountdownFilter(status: .finished)
        )

        XCTAssertEqual(finished.map(\.title), ["Beta"])
    }
}
