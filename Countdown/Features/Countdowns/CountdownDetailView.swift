import CountdownShared
import SwiftUI

struct CountdownDetailContainer: View {
    let snapshot: CountdownSnapshot?
    let onEdit: (CountdownSnapshot) -> Void
    let onDelete: (CountdownSnapshot) -> Void
    let onCreate: () -> Void

    var body: some View {
        if let snapshot {
            CountdownDetailView(
                snapshot: snapshot,
                onEdit: onEdit,
                onDelete: onDelete
            )
        } else {
            ContentUnavailableView(
                "Select a Countdown",
                systemImage: "calendar",
                description: Text("Create or select a countdown to see details.")
            )
        }
    }
}

private struct CountdownDetailView: View {
    let snapshot: CountdownSnapshot
    let onEdit: (CountdownSnapshot) -> Void
    let onDelete: (CountdownSnapshot) -> Void

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let liveSnapshot = snapshot.recalculated(now: context.date)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 28) {
                        CountdownRingView(
                            progress: liveSnapshot.progress,
                            lineWidth: 14,
                            accentColor: liveSnapshot.colorName.countdownColor
                        )
                        .frame(width: 170, height: 170)

                        VStack(alignment: .leading, spacing: 16) {
                            Label(liveSnapshot.status.title, systemImage: liveSnapshot.symbolName)
                                .font(.headline)
                                .foregroundStyle(liveSnapshot.colorName.countdownColor)

                            Text(liveSnapshot.title)
                                .font(.system(size: 38, weight: .semibold, design: .rounded))
                                .lineLimit(3)
                                .minimumScaleFactor(0.65)

                            Text(CountdownFormatter.string(
                                remainingSeconds: liveSnapshot.remainingSeconds,
                                precision: .full
                            ))
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(liveSnapshot.status == .expired ? .secondary : .primary)
                            .accessibilityLabel(CountdownFormatter.accessibilityString(
                                remainingSeconds: liveSnapshot.remainingSeconds,
                                status: liveSnapshot.status
                            ))
                        }
                        Spacer(minLength: 0)
                    }

                    detailGrid(liveSnapshot)
                }
                .padding(32)
                .frame(maxWidth: 920, alignment: .leading)
            }
            .navigationTitle(liveSnapshot.title)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        onEdit(liveSnapshot)
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }

                    Button(role: .destructive) {
                        onDelete(liveSnapshot)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .keyboardShortcut(.delete, modifiers: .command)
                }
            }
        }
    }

    @ViewBuilder
    private func detailGrid(_ snapshot: CountdownSnapshot) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 28, verticalSpacing: 14) {
            GridRow {
                Text("Target")
                    .foregroundStyle(.secondary)
                Text(snapshot.targetDate.formatted(date: .abbreviated, time: .shortened))
            }
            GridRow {
                Text("Created")
                    .foregroundStyle(.secondary)
                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            GridRow {
                Text("Status")
                    .foregroundStyle(.secondary)
                Text(snapshot.status.title)
            }
            GridRow {
                Text("Progress")
                    .foregroundStyle(.secondary)
                Text("\(Int(snapshot.progress * 100))%")
                    .monospacedDigit()
            }
        }
        .font(.body)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }
}
