import CountdownShared
import SwiftUI
import WidgetKit

public struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    public let entry: CountdownWidgetEntry

    public init(entry: CountdownWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch entry.state {
        case .ready:
            if let snapshot = entry.selectedSnapshot {
                CountdownWidgetCard(snapshot: snapshot, family: family)
                    .widgetURL(CountdownURL.countdown(id: snapshot.id))
            } else {
                WidgetMessageView(title: "No Countdown", message: "Create one in the app.")
            }
        case .empty:
            WidgetMessageView(title: "No Countdowns", message: "Create one in Countdown.")
        case .unavailable:
            WidgetMessageView(title: "Shared Data Missing", message: "Open Countdown to repair storage.")
        }
    }
}

private struct WidgetMessageView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
