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

    public init(
        date: Date,
        configuration: CountdownWidgetConfigurationIntent,
        selectedSnapshot: CountdownSnapshot?,
        snapshots: [CountdownSnapshot],
        state: CountdownWidgetState
    ) {
        self.date = date
        self.configuration = configuration
        self.selectedSnapshot = selectedSnapshot
        self.snapshots = snapshots
        self.state = state
    }
}

struct CountdownWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownWidgetEntry {
        CountdownWidgetEntry(
            date: Date(),
            configuration: CountdownWidgetConfigurationIntent(),
            selectedSnapshot: .placeholder,
            snapshots: [.placeholder],
            state: .ready
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
        return Timeline(entries: [entry], policy: .after(nextRefreshDate(for: entry, now: now)))
    }

    private func entry(
        for configuration: CountdownWidgetConfigurationIntent,
        date: Date
    ) async -> CountdownWidgetEntry {
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
                    state: .empty
                )
            }

            let selected = selectedSnapshot(from: snapshots, configuration: configuration)
            return CountdownWidgetEntry(
                date: date,
                configuration: configuration,
                selectedSnapshot: selected,
                snapshots: snapshots,
                state: .ready
            )
        } catch {
            return CountdownWidgetEntry(
                date: date,
                configuration: configuration,
                selectedSnapshot: nil,
                snapshots: [],
                state: .unavailable
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

        return now.addingTimeInterval(max(5 * 60, min(secondsUntilTarget, 60 * 60)))
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
