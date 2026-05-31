import Foundation
import SwiftData

@Model
public final class CountdownItem {
    @Attribute(.unique) public var id: UUID
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

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        targetDate: Date,
        originalTargetDate: Date? = nil,
        quickDurationSeconds: TimeInterval? = nil,
        pausedRemainingSeconds: TimeInterval? = nil,
        completedAt: Date? = nil,
        notificationIdentifier: String? = nil,
        colorName: String = "blue",
        symbolName: String = "calendar"
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetDate = targetDate
        self.originalTargetDate = originalTargetDate ?? targetDate
        self.quickDurationSeconds = quickDurationSeconds
        self.pausedRemainingSeconds = pausedRemainingSeconds
        self.completedAt = completedAt
        self.notificationIdentifier = notificationIdentifier
        self.colorName = colorName
        self.symbolName = symbolName
    }

    public func snapshot(now: Date = Date()) -> CountdownSnapshot {
        let remaining = CountdownCalculator.remainingSeconds(
            targetDate: targetDate,
            pausedRemainingSeconds: pausedRemainingSeconds,
            now: now
        )
        let duration = CountdownCalculator.originalDurationSeconds(
            createdAt: createdAt,
            originalTargetDate: originalTargetDate,
            quickDurationSeconds: quickDurationSeconds
        )
        let status = CountdownCalculator.status(
            targetDate: targetDate,
            pausedRemainingSeconds: pausedRemainingSeconds,
            completedAt: completedAt,
            now: now
        )

        return CountdownSnapshot(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            targetDate: targetDate,
            originalTargetDate: originalTargetDate,
            quickDurationSeconds: quickDurationSeconds,
            pausedRemainingSeconds: pausedRemainingSeconds,
            completedAt: completedAt,
            notificationIdentifier: notificationIdentifier,
            colorName: colorName,
            symbolName: symbolName,
            remainingSeconds: remaining,
            originalDurationSeconds: duration,
            progress: CountdownCalculator.progress(
                remainingSeconds: remaining,
                originalDurationSeconds: duration
            ),
            status: status
        )
    }
}
