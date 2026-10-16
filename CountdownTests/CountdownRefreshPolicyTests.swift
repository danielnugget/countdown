import XCTest
import CountdownShared

final class CountdownRefreshPolicyTests: XCTestCase {
    func testRefreshIntervalsMatchVisiblePrecision() {
        XCTAssertEqual(CountdownRefreshPolicy.interval(remainingSeconds: 90_000, precision: .automatic), 3_600)
        XCTAssertEqual(CountdownRefreshPolicy.interval(remainingSeconds: 7_200, precision: .compact), 60)
        XCTAssertEqual(CountdownRefreshPolicy.interval(remainingSeconds: 3_599, precision: .compact), 1)
        XCTAssertEqual(CountdownRefreshPolicy.interval(remainingSeconds: 90_000, precision: .full), 1)
    }

    func testTimelineContainsExactExpirationForFractionalSeconds() throws {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let snapshot = makeSnapshot(now: now, remaining: 2.5)
        let dates = CountdownRefreshPolicy.timelineDates(for: snapshot, precision: .full, now: now)
        XCTAssertEqual(dates, [now, now.addingTimeInterval(1), now.addingTimeInterval(2), snapshot.targetDate])
        XCTAssertEqual(snapshot.recalculated(now: try XCTUnwrap(dates.last)).status, .expired)
    }

    func testCompactTimelineUpdatesMinutesAndTransitionsToSeconds() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let snapshot = makeSnapshot(now: now, remaining: 3_661.5)
        let dates = CountdownRefreshPolicy.timelineDates(for: snapshot, precision: .compact, now: now)
        XCTAssertLessThanOrEqual(dates.count, 300)
        XCTAssertEqual(dates[1].timeIntervalSince(now), 1.501, accuracy: 0.0001)
        XCTAssertTrue(dates.contains { snapshot.recalculated(now: $0).remainingSeconds < 3_600 })
        for (earlier, later) in zip(dates, dates.dropFirst()) { XCTAssertLessThan(earlier, later) }
    }

    func testLongTimelinesAndFinishedCountdownsAvoidSecondEntries() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let snapshot = makeSnapshot(now: now, remaining: 200_000)
        let dates = CountdownRefreshPolicy.timelineDates(for: snapshot, precision: .automatic, now: now)
        XCTAssertLessThan(dates.count, 30)
        XCTAssertGreaterThan(dates[1].timeIntervalSince(now), 1_000)
        let expired = snapshot.recalculated(now: snapshot.targetDate)
        XCTAssertEqual(CountdownRefreshPolicy.timelineDates(for: expired, precision: .full, now: snapshot.targetDate), [snapshot.targetDate])
    }

    private func makeSnapshot(now: Date, remaining: TimeInterval) -> CountdownSnapshot {
        CountdownSnapshot(
            id: UUID(), title: "Timeline", createdAt: now, updatedAt: now,
            targetDate: now.addingTimeInterval(remaining), originalTargetDate: now.addingTimeInterval(remaining),
            quickDurationSeconds: nil, pausedRemainingSeconds: nil, completedAt: nil,
            notificationIdentifier: nil, colorName: "blue", symbolName: "timer",
            remainingSeconds: remaining, originalDurationSeconds: remaining, progress: 0, status: .running
        )
    }
}
