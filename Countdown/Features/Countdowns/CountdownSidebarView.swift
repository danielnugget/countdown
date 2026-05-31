import CountdownShared
import AppKit
import SwiftUI

struct CountdownSidebarView: View {
    let snapshots: [CountdownSnapshot]
    @Binding var selection: UUID?
    @Binding var searchText: String
    let onCreate: () -> Void

    var body: some View {
        List(selection: $selection) {
            ForEach(snapshots) { snapshot in
                CountdownSidebarRow(snapshot: snapshot)
                    .tag(snapshot.id)
                    .contextMenu {
                        Button("Copy Countdown Link") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(
                                CountdownURL.countdown(id: snapshot.id).absoluteString,
                                forType: .string
                            )
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if snapshots.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Countdowns" : "No Results",
                    systemImage: searchText.isEmpty ? "calendar.badge.plus" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Create your first countdown." : "Try a different search.")
                )
                .padding()
            }
        }
        .navigationTitle("Countdown")
    }
}

private struct CountdownSidebarRow: View {
    let snapshot: CountdownSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: snapshot.symbolName)
                .foregroundStyle(snapshot.colorName.countdownColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(snapshot.title)
        .accessibilityValue(CountdownFormatter.accessibilityString(
            remainingSeconds: snapshot.remainingSeconds,
            status: snapshot.status
        ))
    }

    private var subtitle: String {
        if snapshot.status == .expired {
            return "Finished"
        }

        return CountdownFormatter.string(remainingSeconds: snapshot.remainingSeconds)
    }
}
