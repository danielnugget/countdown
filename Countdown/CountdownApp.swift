import AppIntents
import CountdownIntents
import CountdownShared
import SwiftUI
import SwiftData

@main
struct CountdownApp: App {
    private let modelContainer: ModelContainer
    @State private var store: CountdownStore

    init() {
        let settingsStore = CountdownSettingsStore()
        let settings = settingsStore.load()

        do {
            let container = try CountdownContainerFactory.makeSharedContainer()
            self.modelContainer = container
            _store = State(initialValue: CountdownStore(
                modelContainer: container,
                settingsStore: settingsStore,
                notificationScheduler: CountdownNotificationScheduler(),
                initialSettings: settings
            ))
        } catch {
            let fallback = try! CountdownContainerFactory.makeInMemoryContainer()
            self.modelContainer = fallback
            _store = State(initialValue: CountdownStore(
                modelContainer: fallback,
                settingsStore: settingsStore,
                notificationScheduler: CountdownNotificationScheduler(),
                initialSettings: settings,
                initialError: CountdownError.storageUnavailable(error.localizedDescription).localizedDescription
            ))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .modelContainer(modelContainer)
                .preferredColorScheme(store.settings.themePreference.colorScheme)
                .onOpenURL { url in
                    if let id = CountdownURL.parseCountdownID(from: url) {
                        store.selectCountdown(id)
                    }
                }
        }
        .commands {
            CountdownCommands(store: store)
        }
        .defaultWindowPlacement { _, context in
            let display = context.defaultDisplay.visibleRect
            let width = min(max(display.width * 0.66, 900), 1180)
            let height = min(max(display.height * 0.7, 620), 860)
            return WindowPlacement(size: CGSize(width: width, height: height))
        }

        Settings {
            SettingsView()
                .environment(store)
                .preferredColorScheme(store.settings.themePreference.colorScheme)
        }
    }
}

struct CountdownApplicationIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [CountdownIntentsPackage.self]
    }
}

private extension CountdownThemePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
