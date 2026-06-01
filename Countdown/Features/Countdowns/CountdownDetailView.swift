import CountdownShared
import SwiftUI

struct CountdownDetailContainer: View {
    let showsDashboard: Bool
    let snapshot: CountdownSnapshot?
    let dashboardSnapshots: [CountdownSnapshot]
    let filteredSnapshots: [CountdownSnapshot]
    let tags: [String]
    let upcomingCount: Int
    let finishedCount: Int
    let precision: CountdownDisplayPrecision
    let onSelect: (UUID) -> Void
    let onEdit: (CountdownSnapshot) -> Void
    let onDelete: (CountdownSnapshot) -> Void
    let onCreate: () -> Void

    var body: some View {
        if let snapshot {
            CountdownDetailView(
                snapshot: snapshot,
                precision: precision,
                onEdit: onEdit,
                onDelete: onDelete
            )
        } else if showsDashboard {
            CountdownDashboardView(
                snapshots: dashboardSnapshots,
                filteredSnapshots: filteredSnapshots,
                tags: tags,
                upcomingCount: upcomingCount,
                finishedCount: finishedCount,
                precision: precision,
                onSelect: onSelect,
                onCreate: onCreate
            )
        } else {
            ContentUnavailableView(
                "Select a Countdown",
                systemImage: "calendar",
                description: Text("Choose a countdown from the list to see details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Countdown")
        }
    }
}

private struct CountdownDashboardView: View {
    let snapshots: [CountdownSnapshot]
    let filteredSnapshots: [CountdownSnapshot]
    let tags: [String]
    let upcomingCount: Int
    let finishedCount: Int
    let precision: CountdownDisplayPrecision
    let onSelect: (UUID) -> Void
    let onCreate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dashboardHeader

                if let nextUp {
                    NextUpCard(snapshot: nextUp, precision: precision, onSelect: onSelect)
                } else {
                    emptyCard
                }

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                    MetricCard(title: "Total", value: snapshots.count, systemImage: "calendar")
                    MetricCard(title: "Upcoming", value: upcomingCount, systemImage: "calendar.badge.clock")
                    MetricCard(title: "Finished", value: finishedCount, systemImage: "checkmark.circle")
                    MetricCard(title: "Tags", value: tags.count, systemImage: "tag")
                }

                HStack(alignment: .top, spacing: 16) {
                    timelineCard
                    tagsCard
                }
            }
            .padding(32)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .navigationTitle("Overview")
    }

    private var dashboardHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overview")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(filteredSnapshots.count == snapshots.count ? "All countdowns at a glance" : "\(filteredSnapshots.count) countdowns match the current filters")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onCreate) {
                Label("New Countdown", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("New Countdown")
        }
    }

    private var emptyCard: some View {
        DashboardCard {
            ContentUnavailableView(
                snapshots.isEmpty ? "No Countdowns" : "No Matching Upcoming Countdowns",
                systemImage: "calendar.badge.plus",
                description: Text(snapshots.isEmpty ? "Create a countdown to start tracking what matters next." : "Adjust filters or create a new countdown.")
            )
            .frame(maxWidth: .infinity, minHeight: 180)
        }
    }

    private var timelineCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Timeline", systemImage: "calendar")
                    .font(.headline)

                let groups = timelineGroups
                if groups.isEmpty {
                    Text("No upcoming countdowns.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(group.snapshots.prefix(4)) { snapshot in
                                Button {
                                    onSelect(snapshot.id)
                                } label: {
                                    TimelineRow(snapshot: snapshot, precision: precision)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open \(snapshot.title)")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var tagsCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Tags", systemImage: "tag")
                    .font(.headline)

                if tags.isEmpty {
                    Text("Add tags while editing a countdown to make groups easier to find.")
                        .foregroundStyle(.secondary)
                } else {
                    FlowTagRow(tags: tags, limit: nil)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var nextUp: CountdownSnapshot? {
        filteredSnapshots
            .filter { $0.status != .expired }
            .sorted { $0.targetDate < $1.targetDate }
            .first
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: 12)]
    }

    private var timelineGroups: [TimelineGroup] {
        let upcoming = filteredSnapshots
            .filter { $0.status != .expired }
            .sorted { $0.targetDate < $1.targetDate }
        let calendar = Calendar.current
        let today = upcoming.filter { calendar.isDateInToday($0.targetDate) }
        let week = upcoming.filter {
            !calendar.isDateInToday($0.targetDate) && calendar.isDate($0.targetDate, equalTo: Date(), toGranularity: .weekOfYear)
        }
        let later = upcoming.filter {
            !calendar.isDate($0.targetDate, equalTo: Date(), toGranularity: .weekOfYear)
        }

        return [
            TimelineGroup(title: "Today", snapshots: today),
            TimelineGroup(title: "This Week", snapshots: week),
            TimelineGroup(title: "Later", snapshots: later)
        ].filter { !$0.snapshots.isEmpty }
    }
}

private struct TimelineGroup: Identifiable {
    let title: String
    let snapshots: [CountdownSnapshot]

    var id: String { title }
}

private struct NextUpCard: View {
    let snapshot: CountdownSnapshot
    let precision: CountdownDisplayPrecision
    let onSelect: (UUID) -> Void

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let liveSnapshot = snapshot.recalculated(now: context.date)

            DashboardCard {
                HStack(alignment: .center, spacing: 24) {
                    CountdownRingView(
                        progress: liveSnapshot.progress,
                        lineWidth: 12,
                        accentColor: liveSnapshot.colorName.countdownColor
                    )
                    .frame(width: 132, height: 132)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Next Up", systemImage: liveSnapshot.symbolName)
                            .font(.headline)
                            .foregroundStyle(liveSnapshot.colorName.countdownColor)

                        Text(liveSnapshot.title)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(CountdownFormatter.string(
                            remainingSeconds: liveSnapshot.remainingSeconds,
                            precision: precision
                        ))
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.leading)

                        Text(liveSnapshot.targetDate.formatted(date: .complete, time: .shortened))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        onSelect(liveSnapshot.id)
                    } label: {
                        Label("Open", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Open \(liveSnapshot.title)")
                }
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Text(value, format: .number)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TimelineRow: View {
    let snapshot: CountdownSnapshot
    let precision: CountdownDisplayPrecision

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let liveSnapshot = snapshot.recalculated(now: context.date)

            HStack(spacing: 10) {
                Image(systemName: liveSnapshot.symbolName)
                    .foregroundStyle(liveSnapshot.colorName.countdownColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(liveSnapshot.title)
                        .lineLimit(1)
                    Text(liveSnapshot.targetDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(CountdownFormatter.string(remainingSeconds: liveSnapshot.remainingSeconds, precision: precision))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            .contentShape(Rectangle())
        }
    }
}

private struct CountdownDetailView: View {
    let snapshot: CountdownSnapshot
    let precision: CountdownDisplayPrecision
    let onEdit: (CountdownSnapshot) -> Void
    let onDelete: (CountdownSnapshot) -> Void

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let liveSnapshot = snapshot.recalculated(now: context.date)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero(liveSnapshot)

                    LazyVGrid(columns: detailColumns, alignment: .leading, spacing: 14) {
                        scheduleCard(liveSnapshot)
                        progressCard(liveSnapshot)
                    }

                    if !liveSnapshot.tags.isEmpty {
                        DashboardCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Tags", systemImage: "tag")
                                    .font(.headline)
                                FlowTagRow(tags: liveSnapshot.tags, limit: nil)
                            }
                        }
                    }

                    actionsCard(liveSnapshot)
                }
                .padding(32)
                .frame(maxWidth: 940, alignment: .leading)
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

    private var detailColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 300), spacing: 14)]
    }

    private func hero(_ snapshot: CountdownSnapshot) -> some View {
        DashboardCard {
            HStack(alignment: .center, spacing: 28) {
                CountdownRingView(
                    progress: snapshot.progress,
                    lineWidth: 14,
                    accentColor: snapshot.colorName.countdownColor
                )
                .frame(width: 176, height: 176)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: snapshot.symbolName)
                            .font(.title2)
                            .foregroundStyle(snapshot.colorName.countdownColor)
                            .accessibilityHidden(true)

                        StatusPill(status: snapshot.status)
                    }

                    Text(snapshot.title)
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .lineLimit(3)
                        .minimumScaleFactor(0.65)

                    Text(CountdownFormatter.string(
                        remainingSeconds: snapshot.remainingSeconds,
                        precision: precision
                    ))
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(snapshot.status == .expired ? .secondary : .primary)
                    .accessibilityLabel(CountdownFormatter.accessibilityString(
                        remainingSeconds: snapshot.remainingSeconds,
                        status: snapshot.status
                    ))

                    Text(snapshot.targetDate.formatted(date: .complete, time: .shortened))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func scheduleCard(_ snapshot: CountdownSnapshot) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Schedule", systemImage: "calendar")
                    .font(.headline)
                if let collectionName = snapshot.collectionName {
                    DetailLine(title: "Collection", value: collectionName)
                }
                DetailLine(title: "Target", value: snapshot.targetDate.formatted(date: .abbreviated, time: .shortened))
                DetailLine(title: "Created", value: snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                DetailLine(title: "Updated", value: snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func progressCard(_ snapshot: CountdownSnapshot) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                DetailLine(title: "Status", value: snapshot.status.title)
                DetailLine(title: "Complete", value: "\(Int(snapshot.progress * 100))%")
                ProgressView(value: snapshot.progress)
                    .tint(snapshot.colorName.countdownColor)
                    .accessibilityLabel("Progress")
                    .accessibilityValue("\(Int(snapshot.progress * 100)) percent")
            }
        }
    }

    private func actionsCard(_ snapshot: CountdownSnapshot) -> some View {
        DashboardCard {
            HStack(spacing: 12) {
                Button {
                    onEdit(snapshot)
                } label: {
                    Label("Edit Countdown", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    onDelete(snapshot)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct StatusPill: View {
    let status: CountdownStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status == .expired ? .secondary : Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Status \(status.title)")
    }
}

private struct DashboardCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
