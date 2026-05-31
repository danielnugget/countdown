import Foundation
import SwiftData

@ModelActor
public actor CountdownDataActor {
    public func snapshots(
        now: Date = Date(),
        searchText: String = "",
        sort: CountdownSort = .targetDate
    ) throws -> [CountdownSnapshot] {
        let descriptor = FetchDescriptor<CountdownItem>()
        let items = try modelContext.fetch(descriptor)
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = normalizedSearch.isEmpty ? items : items.filter {
            $0.title.localizedCaseInsensitiveContains(normalizedSearch)
        }

        return filtered
            .map { $0.snapshot(now: now) }
            .sorted(by: sort.comparator)
    }

    public func snapshot(id: UUID, now: Date = Date()) throws -> CountdownSnapshot {
        try item(for: id).snapshot(now: now)
    }

    @discardableResult
    public func createCountdown(
        title: String,
        targetDate: Date,
        colorName: String = "blue",
        symbolName: String = "calendar",
        now: Date = Date()
    ) throws -> CountdownSnapshot {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw CountdownError.invalidTitle
        }

        guard targetDate > now else {
            throw CountdownError.invalidTargetDate
        }

        let notificationIdentifier = "countdown-\(UUID().uuidString)"
        let item = CountdownItem(
            title: trimmedTitle,
            createdAt: now,
            updatedAt: now,
            targetDate: targetDate,
            originalTargetDate: targetDate,
            notificationIdentifier: notificationIdentifier,
            colorName: colorName,
            symbolName: symbolName
        )

        modelContext.insert(item)
        try modelContext.save()
        return item.snapshot(now: now)
    }

    public func deleteCountdown(id: UUID) throws {
        let item = try item(for: id)
        modelContext.delete(item)
        try modelContext.save()
    }

    @discardableResult
    public func updateCountdown(
        id: UUID,
        title: String,
        targetDate: Date,
        colorName: String,
        symbolName: String,
        now: Date = Date()
    ) throws -> CountdownSnapshot {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw CountdownError.invalidTitle
        }
        guard targetDate > now else {
            throw CountdownError.invalidTargetDate
        }

        let item = try item(for: id)
        item.title = trimmedTitle
        item.targetDate = targetDate
        item.originalTargetDate = targetDate
        item.quickDurationSeconds = nil
        item.pausedRemainingSeconds = nil
        item.completedAt = nil
        item.colorName = colorName
        item.symbolName = symbolName
        item.updatedAt = now
        try modelContext.save()
        return item.snapshot(now: now)
    }

    @discardableResult
    public func markExpiredCountdowns(now: Date = Date()) throws -> [CountdownSnapshot] {
        let descriptor = FetchDescriptor<CountdownItem>()
        let items = try modelContext.fetch(descriptor)
        var changed = false

        for item in items where item.pausedRemainingSeconds == nil && item.targetDate <= now && item.completedAt == nil {
            item.completedAt = now
            item.updatedAt = now
            changed = true
        }

        if changed {
            try modelContext.save()
        }

        return items.map { $0.snapshot(now: now) }.sorted(by: CountdownSort.targetDate.comparator)
    }

    private func item(for id: UUID) throws -> CountdownItem {
        var descriptor = FetchDescriptor<CountdownItem>(
            predicate: #Predicate<CountdownItem> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1

        guard let item = try modelContext.fetch(descriptor).first else {
            throw CountdownError.countdownNotFound
        }

        return item
    }
}

private extension CountdownSort {
    var comparator: @Sendable (CountdownSnapshot, CountdownSnapshot) -> Bool {
        switch self {
        case .targetDate:
            { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.targetDate < rhs.targetDate
                }
                return lhs.status.sortRank < rhs.status.sortRank
            }
        case .title:
            { lhs, rhs in lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
        case .createdDate:
            { lhs, rhs in lhs.createdAt < rhs.createdAt }
        }
    }
}

private extension CountdownStatus {
    var sortRank: Int {
        switch self {
        case .running: 0
        case .paused: 1
        case .expired: 2
        }
    }
}
