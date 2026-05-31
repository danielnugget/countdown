import Foundation
import SwiftData

public enum CountdownContainerFactory {
    public static var schema: Schema {
        Schema([CountdownItem.self])
    }

    public static func makeSharedContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "CountdownData",
            schema: schema,
            allowsSave: true,
            groupContainer: .identifier(CountdownConstants.appGroupIdentifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "CountdownData",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public static func appGroupContainerURL(
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: CountdownConstants.appGroupIdentifier
        )
    }

    public static func validateAppGroupAccess(
        fileManager: FileManager = .default
    ) -> Bool {
        guard let url = appGroupContainerURL(fileManager: fileManager) else {
            return false
        }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        } catch {
            return false
        }
    }
}
