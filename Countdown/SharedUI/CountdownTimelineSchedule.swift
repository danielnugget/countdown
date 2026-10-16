import SwiftUI

/// Keep the one-second live display, but stop scheduling work when it cannot change.
struct CountdownTimelineSchedule: TimelineSchedule {
    let deadline: Date?

    func entries(from startDate: Date, mode: Mode) -> AnySequence<Date> {
        guard let deadline, deadline > startDate else { return AnySequence([startDate]) }
        let periodic = PeriodicTimelineSchedule(from: startDate, by: 1)
        return AnySequence(periodic.entries(from: startDate, mode: mode).prefix {
            $0 < deadline.addingTimeInterval(1)
        })
    }
}
