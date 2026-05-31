import AppIntents
import CountdownShared
import Foundation
import WidgetKit

public struct CreateCountdownIntent: AppIntent {
    public static var title: LocalizedStringResource = "Create Countdown"
    public static var description = IntentDescription("Create a countdown for a specific date and time.")
    public static var supportedModes: IntentModes { .background }

    @Parameter(title: "Title")
    public var title: String

    @Parameter(title: "Target Date", kind: .dateTime)
    public var targetDate: Date

    public init() {}

    public init(title: String, targetDate: Date) {
        self.title = title
        self.targetDate = targetDate
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = try await CountdownIntentRunner.createCountdown(
            title: title,
            targetDate: targetDate
        )
        return .result(dialog: "Created \(snapshot.title).")
    }
}

public struct DeleteCountdownIntent: AppIntent {
    public static var title: LocalizedStringResource = "Delete Countdown"
    public static var description = IntentDescription("Delete a countdown.")
    public static var supportedModes: IntentModes { .background }

    @Parameter(title: "Countdown")
    public var countdown: CountdownEntity

    public init() {}

    public init(countdown: CountdownEntity) {
        self.countdown = countdown
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await CountdownIntentRunner.delete(id: countdown.id)
        return .result(dialog: "Deleted \(countdown.title).")
    }
}

public struct OpenCountdownIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Countdown"
    public static var description = IntentDescription("Open Countdown to a specific countdown.")
    public static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Countdown")
    public var countdown: CountdownEntity

    public init() {}

    public init(countdown: CountdownEntity) {
        self.countdown = countdown
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        CountdownHandoffStore.setOpenCountdownID(countdown.id)
        return .result(dialog: "Opening \(countdown.title).")
    }
}

enum CountdownIntentRunner {
    static func createCountdown(
        title: String,
        targetDate: Date,
        now: Date = Date()
    ) async throws -> CountdownSnapshot {
        let container = try CountdownContainerFactory.makeSharedContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let snapshot = try await actor.createCountdown(
            title: title,
            targetDate: targetDate,
            now: now
        )
        reloadWidgets()
        return snapshot
    }

    static func delete(id: UUID) async throws {
        let container = try CountdownContainerFactory.makeSharedContainer()
        let actor = CountdownDataActor(modelContainer: container)
        try await actor.deleteCountdown(id: id)
        reloadWidgets()
    }

    private static func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: CountdownConstants.widgetKind)
    }
}
