import AppKit
import CoreData
import Foundation

@MainActor
final class CountdownSystemEventObserver {
    private var observers: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter

    init(
        notificationCenter: NotificationCenter = .default,
        onEvent: @escaping () -> Void,
        onDataChange: @escaping () -> Void = {}
    ) {
        self.notificationCenter = notificationCenter
        observers.append(notificationCenter.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            onDataChange()
        })
        observers.append(notificationCenter.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { _ in
            onEvent()
        })
        observers.append(notificationCenter.addObserver(
            forName: .NSCalendarDayChanged,
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
            notificationCenter.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
