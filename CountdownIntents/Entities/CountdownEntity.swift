import AppIntents
import CountdownShared
import Foundation

public struct CountdownEntity: AppEntity, Codable, Hashable, Sendable {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Countdown"
    public static var defaultQuery = CountdownEntityQuery()

    public let id: UUID
    public let title: String
    public let subtitle: String
    public let status: CountdownStatus

    public init(snapshot: CountdownSnapshot) {
        self.id = snapshot.id
        self.title = snapshot.title
        self.subtitle = CountdownFormatter.string(remainingSeconds: snapshot.remainingSeconds)
        self.status = snapshot.status
    }

    public init(id: UUID, title: String, subtitle: String = "", status: CountdownStatus = .running) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.status = status
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(displaySubtitle)"
        )
    }

    private var displaySubtitle: String {
        if status == .expired {
            return subtitle.isEmpty ? "Finished" : "\(subtitle) - Finished"
        }

        return subtitle
    }
}

public struct CountdownEntityQuery: EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [CountdownEntity.ID]) async throws -> [CountdownEntity] {
        let container = try CountdownContainerFactory.makeSharedContainer()
        let actor = CountdownDataActor(modelContainer: container)
        let snapshots = try await actor.snapshots()
        let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0].map(CountdownEntity.init(snapshot:)) }
    }

    public func entities(matching string: String) async throws -> [CountdownEntity] {
        let container = try CountdownContainerFactory.makeSharedContainer()
        let actor = CountdownDataActor(modelContainer: container)
        return try await actor.snapshots(searchText: string)
            .prefix(12)
            .map(CountdownEntity.init(snapshot:))
    }

    public func suggestedEntities() async throws -> [CountdownEntity] {
        let container = try CountdownContainerFactory.makeSharedContainer()
        let actor = CountdownDataActor(modelContainer: container)
        return try await actor.snapshots()
            .prefix(12)
            .map(CountdownEntity.init(snapshot:))
    }
}
