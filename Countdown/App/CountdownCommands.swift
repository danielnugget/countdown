import SwiftUI

struct CountdownCommands: Commands {
    let store: CountdownStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Countdown") {
                NotificationCenter.default.post(name: .countdownShowNewEditor, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Countdown") {
            Button("Delete") {
                Task {
                    if let snapshot = store.selectedSnapshot {
                        await store.delete(snapshot)
                    }
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(store.selectedSnapshot == nil)
        }
    }
}
