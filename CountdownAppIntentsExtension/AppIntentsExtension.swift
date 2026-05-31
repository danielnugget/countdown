import AppIntents
import CountdownIntents
import ExtensionFoundation

@main
struct CountdownAppIntentsExtension: AppIntentsExtension {
}

struct CountdownAppIntentsExtensionPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [CountdownIntentsPackage.self]
    }
}
