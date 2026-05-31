import AppKit
import CountdownShared
import SwiftUI

struct MenuBarCountdownView: View {
    @Environment(CountdownStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.snapshots.isEmpty {
                Text("No countdowns")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.snapshots.prefix(5)) { snapshot in
                    Button {
                        store.selectCountdown(snapshot.id)
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        HStack {
                            Image(systemName: snapshot.symbolName)
                            Text(snapshot.title)
                            Spacer()
                            Text(CountdownFormatter.string(remainingSeconds: snapshot.remainingSeconds))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            Button("New Countdown") {
                NotificationCenter.default.post(name: .countdownShowNewEditor, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Open Countdown") {
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Quit Countdown") {
                NSApp.terminate(nil)
            }
        }
        .frame(minWidth: 280)
        .task {
            await store.refresh()
        }
    }
}
