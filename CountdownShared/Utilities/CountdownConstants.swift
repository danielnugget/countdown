import Foundation

public enum CountdownConstants {
    public static let appGroupIdentifier = "T39Z7ZC6ZL.Countdown"
    public static let widgetKind = "CountdownWidget"
    public static let settingsKey = "CountdownAppSettings"
    public static let openCountdownHandoffKey = "CountdownOpenCountdownID"
    public static let urlScheme = "countdown"
}

public enum CountdownURL {
    public static func countdown(id: UUID) -> URL {
        URL(string: "\(CountdownConstants.urlScheme)://countdown/\(id.uuidString)")!
    }

    public static func parseCountdownID(from url: URL) -> UUID? {
        guard url.scheme == CountdownConstants.urlScheme, url.host == "countdown" else {
            return nil
        }

        let pathID = url.pathComponents.dropFirst().first
        return pathID.flatMap(UUID.init(uuidString:))
    }
}

public enum CountdownHandoffStore {
    public static func setOpenCountdownID(_ id: UUID?) {
        guard let defaults = UserDefaults(suiteName: CountdownConstants.appGroupIdentifier) else {
            return
        }

        if let id {
            defaults.set(id.uuidString, forKey: CountdownConstants.openCountdownHandoffKey)
        } else {
            defaults.removeObject(forKey: CountdownConstants.openCountdownHandoffKey)
        }
    }

    public static func consumeOpenCountdownID() -> UUID? {
        guard let defaults = UserDefaults(suiteName: CountdownConstants.appGroupIdentifier),
              let value = defaults.string(forKey: CountdownConstants.openCountdownHandoffKey),
              let id = UUID(uuidString: value) else {
            return nil
        }

        defaults.removeObject(forKey: CountdownConstants.openCountdownHandoffKey)
        return id
    }
}
