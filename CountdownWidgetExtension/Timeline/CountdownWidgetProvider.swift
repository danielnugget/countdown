import CountdownIntents
import CountdownShared
import Foundation
import WidgetKit

public enum CountdownWidgetState: Sendable {
    case ready
    case empty
    case unavailable
}

public struct CountdownWidgetEntry: TimelineEntry, Sendable {
    public let date: Date
    public let configuration: CountdownWidgetConfigurationIntent
    public let selectedSnapshot: CountdownSnapshot?
    public let snapshots: [CountdownSnapshot]
    public let state: CountdownWidgetState
    public let displayPrecision: CountdownDisplayPrecision

    public init(
        date: Date,
        configuration: CountdownWidgetConfigurationIntent,
        selectedSnapshot: CountdownSnapshot?,
        snapshots: [CountdownSnapshot],
        state: CountdownWidgetState,
        displayPrecision: CountdownDisplayPrecision
    ) {
        self.date = date
        self.configuration = configuration
        self.selectedSnapshot = selectedSnapshot
        self.snapshots = snapshots
        self.state = state
        self.displayPrecision = displayPrecision
    }
}

struct CountdownWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownWidgetEntry {
        CountdownWidgetEntry(
            date: Date(),
            configuration: CountdownWidgetConfigurationIntent(),
            selectedSnapshot: .placeholder,
            snapshots: [.placeholder],
            state: .ready,
            displayPrecision: .automatic
        )
    }

    func snapshot(
        for configuration: CountdownWidgetConfigurationIntent,
        in context: Context
    ) async -> CountdownWidgetEntry {
        await entry(for: configuration, date: Date())
    }

    func timeline(
        for configuration: CountdownWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<CountdownWidgetEntry> {
        let now = Date()
        let entry = await entry(for: configuration, date: now)
        let entries = timelineEntries(from: entry, now: now)
        let reloadDate = nextRefreshDate(for: entry, entries: entries, now: now)
        return Timeline(entries: entries, policy: .after(reloadDate))
    }

    private func entry(
        for configuration: CountdownWidgetConfigurationIntent,
        date: Date
    ) async -> CountdownWidgetEntry {
        let displayPrecision = CountdownSettingsStore().load().displayPrecision

        do {
            let container = try CountdownContainerFactory.makeSharedContainer()
            let actor = CountdownDataActor(modelContainer: container)
            let snapshots = try await actor.snapshots(now: date)

            guard !snapshots.isEmpty else {
                return CountdownWidgetEntry(
                    date: date,
                    configuration: configuration,
                    selectedSnapshot: nil,
                    snapshots: [],
                    state: .empty,
                    displayPrecision: displayPrecision
                )
            }

            let selected = selectedSnapshot(from: snapshots, configuration: configuration)
            return CountdownWidgetEntry(
                date: date,
                configuration: configuration,
                selectedSnapshot: selected,
                snapshots: snapshots,
                state: .ready,
                displayPrecision: displayPrecision
            )
        } catch {
            return CountdownWidgetEntry(
                date: date,
                configuration: configuration,
                selectedSnapshot: nil,
                snapshots: [],
                state: .unavailable,
                displayPrecision: displayPrecision
            )
        }
    }

    private func selectedSnapshot(
        from snapshots: [CountdownSnapshot],
        configuration: CountdownWidgetConfigurationIntent
    ) -> CountdownSnapshot? {
        if let configuredID = configuration.countdown?.id,
           let snapshot = snapshots.first(where: { $0.id == configuredID }) {
            return snapshot
        }

        return snapshots.first(where: { $0.status == .running }) ?? snapshots.first
    }

    private func nextRefreshDate(for entry: CountdownWidgetEntry, now: Date) -> Date {
        guard let selected = entry.selectedSnapshot, selected.status == .running else {
            return now.addingTimeInterval(15 * 60)
        }

        let secondsUntilTarget = selected.targetDate.timeIntervalSince(now)
        if secondsUntilTarget <= 0 {
            return now.addingTimeInterval(15 * 60)
        }

        if displaysSeconds(
            remainingSeconds: selected.remainingSeconds,
            precision: entry.displayPrecision
        ) {
            return now.addingTimeInterval(min(secondsUntilTarget, 60))
        }

        return now.addingTimeInterval(max(5 * 60, min(secondsUntilTarget, 60 * 60)))
    }

    private func nextRefreshDate(
        for entry: CountdownWidgetEntry,
        entries: [CountdownWidgetEntry],
        now: Date
    ) -> Date {
        guard entries.count > 1, let lastEntryDate = entries.last?.date else {
            return nextRefreshDate(for: entry, now: now)
        }

        return lastEntryDate.addingTimeInterval(1)
    }

    private func timelineEntries(
        from entry: CountdownWidgetEntry,
        now: Date
    ) -> [CountdownWidgetEntry] {
        guard let selected = entry.selectedSnapshot,
              selected.status == .running,
              displaysSeconds(
                remainingSeconds: selected.remainingSeconds,
                precision: entry.displayPrecision
              ) else {
            return [entry]
        }

        let entryCount = max(1, min(5 * 60, Int(ceil(selected.remainingSeconds)) + 1))
        return (0..<entryCount).map { offset in
            let date = now.addingTimeInterval(TimeInterval(offset))
            return CountdownWidgetEntry(
                date: date,
                configuration: entry.configuration,
                selectedSnapshot: selected.recalculated(now: date),
                snapshots: entry.snapshots,
                state: entry.state,
                displayPrecision: entry.displayPrecision
            )
        }
    }

    private func displaysSeconds(
        remainingSeconds: TimeInterval,
        precision: CountdownDisplayPrecision
    ) -> Bool {
        let parts = CountdownFormatter.parts(from: remainingSeconds)

        switch precision {
        case .full:
            return true
        case .automatic:
            return parts.days == 0
        case .compact:
            return parts.days == 0 && parts.hours == 0
        }
    }
}

private extension CountdownSnapshot {
    static var placeholder: CountdownSnapshot {
        let now = Date()
        let target = now.addingTimeInterval(42 * 60)
        return CountdownSnapshot(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Design Review",
            createdAt: now,
            updatedAt: now,
            targetDate: target,
            originalTargetDate: target,
            quickDurationSeconds: nil,
            pausedRemainingSeconds: nil,
            completedAt: nil,
            notificationIdentifier: nil,
            colorName: "blue",
            symbolName: "timer",
            remainingSeconds: target.timeIntervalSince(now),
            originalDurationSeconds: 3_600,
            progress: 0.3,
            status: .running
        )
    }
}
