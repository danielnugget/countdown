import CountdownIntents
import CountdownShared
import SwiftUI
import WidgetKit

struct CountdownWidget: Widget {
    let kind = CountdownConstants.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CountdownWidgetConfigurationIntent.self,
            provider: CountdownWidgetProvider()
        ) { entry in
            CountdownWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Countdown")
        .description("Track one of your countdowns.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct CountdownWidgetBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
    }
}
