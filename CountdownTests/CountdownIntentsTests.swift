import AppIntents
import XCTest
@testable import CountdownIntents
@testable import CountdownShared

final class CountdownIntentsTests: XCTestCase {
    func testCountdownEntityUsesSnapshotDisplayData() {
        let now = Date(timeIntervalSinceReferenceDate: 30_000)
        let snapshot = CountdownSnapshot(
            id: UUID(),
            title: "Board Meeting",
            createdAt: now,
            updatedAt: now,
            targetDate: now.addingTimeInterval(600),
            originalTargetDate: now.addingTimeInterval(600),
            quickDurationSeconds: nil,
            pausedRemainingSeconds: nil,
            completedAt: nil,
            notificationIdentifier: nil,
            colorName: "blue",
            symbolName: "calendar",
            remainingSeconds: 600,
            originalDurationSeconds: 1_200,
            progress: 0.5,
            status: .running
        )

        let entity = CountdownEntity(snapshot: snapshot)

        XCTAssertEqual(entity.id, snapshot.id)
        XCTAssertEqual(entity.title, "Board Meeting")
        XCTAssertEqual(entity.status, .running)
    }

    func testIntentInitializersProvideValidationExamples() {
        let target = Date().addingTimeInterval(600)
        let create = CreateCountdownIntent(title: "Ship", targetDate: target)
        let quick = StartQuickTimerIntent(title: "Break", minutes: 10)
        let entity = CountdownEntity(id: UUID(), title: "Ship")

        XCTAssertEqual(create.title, "Ship")
        XCTAssertEqual(create.targetDate, target)
        XCTAssertEqual(quick.title, "Break")
        XCTAssertEqual(quick.minutes, 10)
        XCTAssertEqual(PauseCountdownIntent(countdown: entity).countdown.id, entity.id)
        XCTAssertEqual(ResumeCountdownIntent(countdown: entity).countdown.id, entity.id)
        XCTAssertEqual(DeleteCountdownIntent(countdown: entity).countdown.id, entity.id)
        XCTAssertEqual(OpenCountdownIntent(countdown: entity).countdown.id, entity.id)
    }
}
