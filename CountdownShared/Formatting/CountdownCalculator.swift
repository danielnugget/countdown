import Foundation

public enum CountdownCalculator {
    public static func remainingSeconds(
        targetDate: Date,
        pausedRemainingSeconds: TimeInterval?,
        now: Date
    ) -> TimeInterval {
        if let pausedRemainingSeconds {
            return max(0, pausedRemainingSeconds)
        }

        return max(0, targetDate.timeIntervalSince(now))
    }

    public static func originalDurationSeconds(
        createdAt: Date,
        originalTargetDate: Date,
        quickDurationSeconds: TimeInterval?
    ) -> TimeInterval {
        max(1, quickDurationSeconds ?? originalTargetDate.timeIntervalSince(createdAt))
    }

    public static func progress(
        remainingSeconds: TimeInterval,
        originalDurationSeconds: TimeInterval
    ) -> Double {
        guard originalDurationSeconds > 0 else {
            return 1
        }

        let elapsed = max(0, originalDurationSeconds - remainingSeconds)
        return min(1, max(0, elapsed / originalDurationSeconds))
    }

    public static func status(
        targetDate: Date,
        pausedRemainingSeconds: TimeInterval?,
        completedAt: Date?,
        now: Date
    ) -> CountdownStatus {
        if completedAt != nil || targetDate <= now, pausedRemainingSeconds == nil {
            return .expired
        }

        if pausedRemainingSeconds != nil {
            return .paused
        }

        return .running
    }

    public static func notificationDate(
        targetDate: Date,
        pausedRemainingSeconds: TimeInterval?,
        now: Date
    ) -> Date? {
        guard pausedRemainingSeconds == nil, targetDate > now else {
            return nil
        }

        return targetDate
    }
}
