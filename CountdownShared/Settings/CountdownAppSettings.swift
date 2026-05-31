import Foundation

public enum CountdownThemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

public enum CountdownDisplayPrecision: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case compact
    case full

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .compact: "Compact"
        case .full: "Full"
        }
    }
}

public struct CountdownAppSettings: Codable, Equatable, Sendable {
    public var notificationsEnabled: Bool
    public var themePreference: CountdownThemePreference
    public var displayPrecision: CountdownDisplayPrecision

    public init(
        notificationsEnabled: Bool = true,
        themePreference: CountdownThemePreference = .system,
        displayPrecision: CountdownDisplayPrecision = .automatic
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.themePreference = themePreference
        self.displayPrecision = displayPrecision
    }
}

public final class CountdownSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults? = UserDefaults(suiteName: CountdownConstants.appGroupIdentifier),
        key: String = CountdownConstants.settingsKey
    ) {
        self.defaults = defaults ?? .standard
        self.key = key
    }

    public func load() -> CountdownAppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(CountdownAppSettings.self, from: data) else {
            return CountdownAppSettings()
        }

        return settings
    }

    public func save(_ settings: CountdownAppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
