import Foundation

public struct CountdownTimeParts: Codable, Equatable, Sendable {
    public var days: Int
    public var hours: Int
    public var minutes: Int
    public var seconds: Int

    public init(days: Int, hours: Int, minutes: Int, seconds: Int) {
        self.days = days
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}

public enum CountdownFormatter {
    public static func parts(from remainingSeconds: TimeInterval) -> CountdownTimeParts {
        let clamped = max(0, Int(remainingSeconds.rounded(.down)))
        let days = clamped / 86_400
        let hours = (clamped % 86_400) / 3_600
        let minutes = (clamped % 3_600) / 60
        let seconds = clamped % 60
        return CountdownTimeParts(days: days, hours: hours, minutes: minutes, seconds: seconds)
    }

    public static func string(
        remainingSeconds: TimeInterval,
        precision: CountdownDisplayPrecision = .automatic
    ) -> String {
        let parts = parts(from: remainingSeconds)

        switch precision {
        case .compact:
            if parts.days > 0 { return "\(parts.days)d \(parts.hours)h" }
            if parts.hours > 0 { return "\(parts.hours)h \(parts.minutes)m" }
            if parts.minutes > 0 { return "\(parts.minutes)m \(parts.seconds)s" }
            return "\(parts.seconds)s"
        case .full:
            return fullString(parts: parts, separator: "\n")
        case .automatic:
            if parts.days > 0 {
                return "\(parts.days)d \(parts.hours)h"
            }
            return String(format: "%02d:%02d:%02d", parts.hours, parts.minutes, parts.seconds)
        }
    }

    public static func accessibilityString(
        remainingSeconds: TimeInterval,
        status: CountdownStatus
    ) -> String {
        if status == .expired {
            return "Finished"
        }

        let prefix = status == .paused ? "Paused with" : "Remaining"
        return "\(prefix) \(fullString(parts: parts(from: remainingSeconds), separator: ", "))"
    }

    private static func fullString(parts: CountdownTimeParts, separator: String) -> String {
        var components: [String] = []
        if parts.days > 0 { components.append("\(parts.days) \(parts.days == 1 ? "day" : "days")") }
        if parts.hours > 0 { components.append("\(parts.hours) \(parts.hours == 1 ? "hour" : "hours")") }
        if parts.minutes > 0 { components.append("\(parts.minutes) \(parts.minutes == 1 ? "minute" : "minutes")") }
        if parts.seconds > 0 || components.isEmpty { components.append("\(parts.seconds) \(parts.seconds == 1 ? "second" : "seconds")") }
        return components.joined(separator: separator)
    }
}
