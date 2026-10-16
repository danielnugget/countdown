import Foundation

public enum CountdownRefreshPolicy {
    public static func interval(
        remainingSeconds: TimeInterval,
        precision: CountdownDisplayPrecision
    ) -> TimeInterval {
        switch precision {
        case .full: 1
        case .automatic: remainingSeconds >= 86_400 ? 3_600 : 1
        case .compact: remainingSeconds >= 86_400 ? 3_600 : (remainingSeconds >= 3_600 ? 60 : 1)
        }
    }

    /// Bounded timelines follow the visible unit, including its transition to seconds and expiry.
    public static func timelineDates(
        for snapshot: CountdownSnapshot,
        precision: CountdownDisplayPrecision,
        now: Date
    ) -> [Date] {
        let current = snapshot.recalculated(now: now)
        guard current.status == .running else { return [now] }
        let firstInterval = interval(remainingSeconds: current.remainingSeconds, precision: precision)
        let horizon = now.addingTimeInterval(firstInterval == 1 ? 299 : (firstInterval == 60 ? 3_600 : 86_400))
        var dates = [now]
        var date = now
        while dates.count < 300 && date < horizon && date < snapshot.targetDate {
            let remaining = snapshot.targetDate.timeIntervalSince(date)
            let unit = interval(remainingSeconds: remaining, precision: precision)
            // Cross the formatting boundary rather than landing just before it through rounding.
            let step = unit == 1 ? 1 : remaining.truncatingRemainder(dividingBy: unit) + 0.001
            date = min(snapshot.targetDate, horizon, date.addingTimeInterval(max(0.001, step)))
            dates.append(date)
        }
        return dates
    }
}
