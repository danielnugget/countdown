import Foundation

/// The same in-memory query is used by the app, widgets, and intents.
public enum CountdownSnapshotQuery {
    public static func apply(
        to snapshots: [CountdownSnapshot],
        searchText: String = "",
        sort: CountdownSort? = .targetDate,
        filter: CountdownFilter = CountdownFilter()
    ) -> [CountdownSnapshot] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagKeys = Set(filter.tags.map(CountdownTagNormalizer.key(for:)))
        let collectionKey = filter.collectionName.map(CountdownCollectionNormalizer.key(for:))

        let matches = snapshots.filter { snapshot in
            guard filter.status.includes(snapshot.status) else { return false }
            if let collectionKey {
                guard let name = snapshot.collectionName,
                      CountdownCollectionNormalizer.key(for: name) == collectionKey else { return false }
            }
            if !tagKeys.isEmpty {
                let keys = Set(snapshot.tags.map(CountdownTagNormalizer.key(for:)))
                guard tagKeys.isSubset(of: keys) else { return false }
            }
            return search.isEmpty
                || snapshot.title.localizedCaseInsensitiveContains(search)
                || snapshot.tags.contains { $0.localizedCaseInsensitiveContains(search) }
                || snapshot.collectionName?.localizedCaseInsensitiveContains(search) == true
        }
        guard let sort else { return matches }
        return matches.sorted(by: sort.comparator)
    }
}

extension CountdownSort {
    var comparator: @Sendable (CountdownSnapshot, CountdownSnapshot) -> Bool {
        { lhs, rhs in
            switch self {
            case .targetDate:
                if lhs.status != rhs.status { return lhs.status.sortRank < rhs.status.sortRank }
                if lhs.targetDate != rhs.targetDate { return lhs.targetDate < rhs.targetDate }
            case .title:
                let order = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if order != .orderedSame { return order == .orderedAscending }
            case .createdDate:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            }
            return lhs.id.uuidString < rhs.id.uuidString
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
