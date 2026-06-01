import Foundation

public final class CountdownCollectionStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults? = UserDefaults(suiteName: CountdownConstants.appGroupIdentifier),
        key: String = "CountdownCollectionsByID"
    ) {
        self.defaults = defaults ?? .standard
        self.key = key
    }

    public func collectionName(for id: UUID) -> String? {
        loadAll()[id]
    }

    public func loadAll() -> [UUID: String] {
        guard let data = defaults.data(forKey: key),
              let storedCollections = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return storedCollections.reduce(into: [:]) { result, element in
            guard let id = UUID(uuidString: element.key),
                  let collectionName = CountdownCollectionNormalizer.normalize(element.value) else {
                return
            }

            result[id] = collectionName
        }
    }

    public func save(_ collectionName: String?, for id: UUID) {
        var storedCollections = loadAll()

        if let collectionName = CountdownCollectionNormalizer.normalize(collectionName) {
            storedCollections[id] = collectionName
        } else {
            storedCollections[id] = nil
        }

        saveAll(storedCollections)
    }

    public func removeCollection(for id: UUID) {
        var storedCollections = loadAll()
        storedCollections[id] = nil
        saveAll(storedCollections)
    }

    private func saveAll(_ collectionsByID: [UUID: String]) {
        let storedCollections = collectionsByID.reduce(into: [String: String]()) { result, element in
            guard let collectionName = CountdownCollectionNormalizer.normalize(element.value) else {
                return
            }

            result[element.key.uuidString] = collectionName
        }

        guard let data = try? JSONEncoder().encode(storedCollections) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
