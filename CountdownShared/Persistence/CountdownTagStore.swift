import Foundation

public final class CountdownTagStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults? = UserDefaults(suiteName: CountdownConstants.appGroupIdentifier),
        key: String = "CountdownTagsByID"
    ) {
        self.defaults = defaults ?? .standard
        self.key = key
    }

    public func tags(for id: UUID) -> [String] {
        loadAll()[id] ?? []
    }

    public func loadAll() -> [UUID: [String]] {
        guard let data = defaults.data(forKey: key),
              let storedTags = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }

        return storedTags.reduce(into: [:]) { result, element in
            guard let id = UUID(uuidString: element.key) else {
                return
            }

            result[id] = CountdownTagNormalizer.normalize(element.value)
        }
    }

    public func save(_ tags: [String], for id: UUID) {
        var storedTags = loadAll()
        let normalizedTags = CountdownTagNormalizer.normalize(tags)

        if normalizedTags.isEmpty {
            storedTags[id] = nil
        } else {
            storedTags[id] = normalizedTags
        }

        saveAll(storedTags)
    }

    public func removeTags(for id: UUID) {
        var storedTags = loadAll()
        storedTags[id] = nil
        saveAll(storedTags)
    }

    private func saveAll(_ tagsByID: [UUID: [String]]) {
        let storedTags = tagsByID.reduce(into: [String: [String]]()) { result, element in
            result[element.key.uuidString] = CountdownTagNormalizer.normalize(element.value)
        }

        guard let data = try? JSONEncoder().encode(storedTags) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
