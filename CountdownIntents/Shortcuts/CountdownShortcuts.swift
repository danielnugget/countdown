import AppIntents

public struct CountdownAppShortcutsProvider: AppShortcutsProvider {
    public static var shortcutTileColor: ShortcutTileColor = .blue

    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateCountdownIntent(),
            phrases: [
                "Create a countdown with \(.applicationName)",
                "Add a countdown in \(.applicationName)"
            ],
            shortTitle: "Create Countdown",
            systemImageName: "calendar.badge.plus"
        )

        AppShortcut(
            intent: OpenCountdownIntent(),
            phrases: [
                "Open a countdown in \(.applicationName)"
            ],
            shortTitle: "Open Countdown",
            systemImageName: "arrow.up.forward.app"
        )
    }
}

public struct CountdownIntentsPackage: AppIntentsPackage {
    public static var includedPackages: [any AppIntentsPackage.Type] {
        []
    }
}
