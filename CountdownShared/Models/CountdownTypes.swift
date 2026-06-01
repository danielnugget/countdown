import Foundation

public enum CountdownStatus: String, Codable, CaseIterable, Sendable {
    case running
    case paused
    case expired

    public var title: String {
        switch self {
        case .running: "Running"
        case .paused: "Paused"
        case .expired: "Finished"
        }
    }
}

public enum CountdownSort: String, Codable, CaseIterable, Identifiable, Sendable {
    case targetDate
    case title
    case createdDate

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .targetDate: "Target Date"
        case .title: "Title"
        case .createdDate: "Created Date"
        }
    }
}

public enum CountdownStatusFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    case all
    case upcoming
    case finished

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: "All"
        case .upcoming: "Upcoming"
        case .finished: "Finished"
        }
    }

    public func includes(_ status: CountdownStatus) -> Bool {
        switch self {
        case .all:
            true
        case .upcoming:
            status != .expired
        case .finished:
            status == .expired
        }
    }
}

public struct CountdownFilter: Codable, Equatable, Sendable {
    public var status: CountdownStatusFilter
    public var tags: [String]
    public var collectionName: String?

    public init(
        status: CountdownStatusFilter = .all,
        tags: [String] = [],
        collectionName: String? = nil
    ) {
        self.status = status
        self.tags = CountdownTagNormalizer.normalize(tags)
        self.collectionName = CountdownCollectionNormalizer.normalize(collectionName)
    }
}

public enum CountdownTagNormalizer {
    public static func normalize(_ tags: [String]) -> [String] {
        var seenKeys: Set<String> = []
        var values: [String] = []

        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let key = key(for: trimmed)
            guard !seenKeys.contains(key) else {
                continue
            }

            seenKeys.insert(key)
            values.append(trimmed)
        }

        return values.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    public static func key(for tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

public enum CountdownCollectionNormalizer {
    public static func normalize(_ collectionName: String?) -> String? {
        guard let collectionName else {
            return nil
        }

        let trimmed = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func normalize(_ collectionNames: [String]) -> [String] {
        var seenKeys: Set<String> = []
        var values: [String] = []

        for collectionName in collectionNames {
            guard let normalized = normalize(collectionName) else {
                continue
            }

            let key = key(for: normalized)
            guard !seenKeys.contains(key) else {
                continue
            }

            seenKeys.insert(key)
            values.append(normalized)
        }

        return values.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    public static func key(for collectionName: String) -> String {
        collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

public struct CountdownSnapshot: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var targetDate: Date
    public var originalTargetDate: Date
    public var quickDurationSeconds: TimeInterval?
    public var pausedRemainingSeconds: TimeInterval?
    public var completedAt: Date?
    public var notificationIdentifier: String?
    public var colorName: String
    public var symbolName: String
    public var remainingSeconds: TimeInterval
    public var originalDurationSeconds: TimeInterval
    public var progress: Double
    public var status: CountdownStatus
    public var tags: [String]
    public var collectionName: String?

    public init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        targetDate: Date,
        originalTargetDate: Date,
        quickDurationSeconds: TimeInterval?,
        pausedRemainingSeconds: TimeInterval?,
        completedAt: Date?,
        notificationIdentifier: String?,
        colorName: String,
        symbolName: String,
        remainingSeconds: TimeInterval,
        originalDurationSeconds: TimeInterval,
        progress: Double,
        status: CountdownStatus,
        tags: [String] = [],
        collectionName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetDate = targetDate
        self.originalTargetDate = originalTargetDate
        self.quickDurationSeconds = quickDurationSeconds
        self.pausedRemainingSeconds = pausedRemainingSeconds
        self.completedAt = completedAt
        self.notificationIdentifier = notificationIdentifier
        self.colorName = colorName
        self.symbolName = symbolName
        self.remainingSeconds = remainingSeconds
        self.originalDurationSeconds = originalDurationSeconds
        self.progress = progress
        self.status = status
        self.tags = CountdownTagNormalizer.normalize(tags)
        self.collectionName = CountdownCollectionNormalizer.normalize(collectionName)
    }

    public var isQuickTimer: Bool {
        quickDurationSeconds != nil
    }

    public var isActive: Bool {
        status == .running
    }

    public func recalculated(now: Date = Date()) -> CountdownSnapshot {
        let remaining = CountdownCalculator.remainingSeconds(
            targetDate: targetDate,
            pausedRemainingSeconds: pausedRemainingSeconds,
            now: now
        )
        let currentStatus = CountdownCalculator.status(
            targetDate: targetDate,
            pausedRemainingSeconds: pausedRemainingSeconds,
            completedAt: completedAt,
            now: now
        )

        var copy = self
        copy.remainingSeconds = remaining
        copy.status = currentStatus
        copy.progress = CountdownCalculator.progress(
            remainingSeconds: remaining,
            originalDurationSeconds: originalDurationSeconds
        )
        return copy
    }
}

public enum CountdownError: LocalizedError, Sendable {
    case appGroupUnavailable
    case countdownNotFound
    case invalidTitle
    case invalidTargetDate
    case invalidDuration
    case storageUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "Countdown could not access its shared App Group container."
        case .countdownNotFound:
            "That countdown no longer exists."
        case .invalidTitle:
            "Enter a countdown title."
        case .invalidTargetDate:
            "Choose a future date and time."
        case .invalidDuration:
            "Choose a duration greater than zero."
        case .storageUnavailable(let reason):
            "Countdown storage is unavailable: \(reason)"
        }
    }
}
