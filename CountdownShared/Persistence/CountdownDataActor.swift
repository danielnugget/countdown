import Foundation
import SwiftData

@ModelActor
public actor CountdownDataActor {
    public func snapshots(
        now: Date = Date(),
        searchText: String = "",
        sort: CountdownSort = .targetDate,
        filter: CountdownFilter = CountdownFilter()
    ) throws -> [CountdownSnapshot] {
        let descriptor = FetchDescriptor<CountdownItem>()
        let items = try modelContext.fetch(descriptor)
        let tagsByID = CountdownTagStore().loadAll()
        let collectionsByID = CountdownCollectionStore().loadAll()

        let snapshots = items.map { item in
            item.snapshot(
                now: now,
                tags: tagsByID[item.id] ?? [],
                collectionName: collectionsByID[item.id]
            )
        }
        return CountdownSnapshotQuery.apply(
            to: snapshots, searchText: searchText, sort: sort, filter: filter
        )
    }

    public func snapshot(id: UUID, now: Date = Date()) throws -> CountdownSnapshot {
        let item = try item(for: id)
        return item.snapshot(
            now: now,
            tags: CountdownTagStore().tags(for: id),
            collectionName: CountdownCollectionStore().collectionName(for: id)
        )
    }

    @discardableResult
    public func createCountdown(
        title: String,
        targetDate: Date,
        colorName: String = "blue",
        symbolName: String = "calendar",
        tags: [String] = [],
        collectionName: String? = nil,
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
        CountdownTagStore().save(tags, for: item.id)
        CountdownCollectionStore().save(collectionName, for: item.id)
        return item.snapshot(now: now, tags: tags, collectionName: collectionName)
    }

    public func deleteCountdown(id: UUID) throws {
        let item = try item(for: id)
        modelContext.delete(item)
        try modelContext.save()
        CountdownTagStore().removeTags(for: id)
        CountdownCollectionStore().removeCollection(for: id)
    }

    @discardableResult
    public func updateCountdown(
        id: UUID,
        title: String,
        targetDate: Date,
        colorName: String,
        symbolName: String,
        tags: [String] = [],
        collectionName: String? = nil,
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
        CountdownTagStore().save(tags, for: id)
        CountdownCollectionStore().save(collectionName, for: id)
        return item.snapshot(now: now, tags: tags, collectionName: collectionName)
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

        let tagsByID = CountdownTagStore().loadAll()
        let collectionsByID = CountdownCollectionStore().loadAll()
        return items
            .map { item in
                item.snapshot(
                    now: now,
                    tags: tagsByID[item.id] ?? [],
                    collectionName: collectionsByID[item.id]
                )
            }
            .sorted(by: CountdownSort.targetDate.comparator)
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
