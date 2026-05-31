import AppKit
import Foundation

@MainActor
final class CountdownSystemEventObserver {
    private var observers: [NSObjectProtocol] = []

    init(onEvent: @escaping () -> Void) {
        let notificationCenter = NotificationCenter.default
        observers.append(notificationCenter.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { _ in
            onEvent()
        })
        observers.append(notificationCenter.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { _ in
            onEvent()
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            onEvent()
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
