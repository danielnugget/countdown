import AppIntents
import CountdownShared
import WidgetKit

public struct CountdownWidgetConfigurationIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Countdown"
    public static var description = IntentDescription("Choose the countdown to display.")
    public static var supportedModes: IntentModes { .background }

    @Parameter(title: "Countdown")
    public var countdown: CountdownEntity?

    public init() {}

    public init(countdown: CountdownEntity?) {
        self.countdown = countdown
    }
}
