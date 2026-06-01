import CountdownShared
import AppKit
import SwiftUI

struct CountdownFilterSidebarView: View {
    let isShowingOverview: Bool
    let statusFilter: CountdownStatusFilter
    let selectedTags: [String]
    let allCount: Int
    let upcomingCount: Int
    let finishedCount: Int
    let tags: [String]
    let tagCount: (String) -> Int
    let onShowDashboard: () -> Void
    let onSelectStatus: (CountdownStatusFilter) -> Void
    let onSelectTag: (String) -> Void
    let onClearFilters: () -> Void

    var body: some View {
        List {
            Section {
                FilterSidebarRow(
                    title: "Overview",
                    systemImage: "rectangle.grid.2x2",
                    count: allCount,
                    isSelected: isShowingOverview,
                    action: onShowDashboard
                )
            }

            Section("Browse") {
                FilterSidebarRow(
                    title: "All",
                    systemImage: "calendar",
                    count: allCount,
                    isSelected: !isShowingOverview && statusFilter == .all && selectedTags.isEmpty,
                    action: { onSelectStatus(.all) }
                )
                FilterSidebarRow(
                    title: "Upcoming",
                    systemImage: "calendar.badge.clock",
                    count: upcomingCount,
                    isSelected: !isShowingOverview && statusFilter == .upcoming,
                    action: { onSelectStatus(.upcoming) }
                )
                FilterSidebarRow(
                    title: "Finished",
                    systemImage: "checkmark.circle",
                    count: finishedCount,
                    isSelected: !isShowingOverview && statusFilter == .finished,
                    action: { onSelectStatus(.finished) }
                )
            }

            if !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        FilterSidebarRow(
                            title: tag,
                            systemImage: "tag",
                            count: tagCount(tag),
                            isSelected: !isShowingOverview && selectedTags.contains(tag),
                            action: { onSelectTag(tag) }
                        )
                    }
                }
            }

            if hasActiveFilters {
                Section {
                    Button(action: onClearFilters) {
                        Label("Clear Filters", systemImage: "xmark.circle")
                    }
                    .accessibilityLabel("Clear filters")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Countdown")
    }

    private var hasActiveFilters: Bool {
        !isShowingOverview && (statusFilter != .all || !selectedTags.isEmpty)
    }
}

private struct FilterSidebarRow: View {
    let title: String
    let systemImage: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 18)

                Text(title)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(count, format: .number)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue("\(count) countdowns")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CountdownListView: View {
    let snapshots: [CountdownSnapshot]
    @Binding var selection: UUID?
    @Binding var sort: CountdownSort
    let filterTitle: String
    let searchText: String
    let onCreate: () -> Void
    let onClearFilters: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            List(selection: $selection) {
                ForEach(snapshots) { snapshot in
                    CountdownListRow(snapshot: snapshot)
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
            .listStyle(.inset)
            .overlay {
                if snapshots.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Countdowns" : "No Results",
                        systemImage: searchText.isEmpty ? "calendar.badge.plus" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Create a countdown or clear filters." : "Try a different search.")
                    )
                    .padding()
                }
            }
        }
        .background(.regularMaterial)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(filterTitle)
                        .font(.headline)
                    Text("\(snapshots.count) shown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                Button(action: onCreate) {
                    Label("New Countdown", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .help("New Countdown")
                .accessibilityLabel("New Countdown")
            }

            HStack(spacing: 10) {
                Picker("Sort", selection: $sort) {
                    ForEach(CountdownSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("Sort countdowns")

                if !searchText.isEmpty {
                    CountdownTagChip(title: searchText, systemImage: "magnifyingglass")
                }

                Spacer(minLength: 0)

                Button(action: onClearFilters) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.borderless)
                .help("Clear Filters")
                .accessibilityLabel("Clear filters")
            }
        }
        .padding(14)
    }
}

private struct CountdownListRow: View {
    let snapshot: CountdownSnapshot

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let liveSnapshot = snapshot.recalculated(now: context.date)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: liveSnapshot.symbolName)
                        .foregroundStyle(liveSnapshot.colorName.countdownColor)
                        .frame(width: 18)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(liveSnapshot.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)

                        Text(liveSnapshot.targetDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(rowTime(for: liveSnapshot))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(liveSnapshot.status == .expired ? .secondary : .primary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                ProgressView(value: liveSnapshot.progress)
                    .tint(liveSnapshot.colorName.countdownColor)
                    .controlSize(.mini)
                    .accessibilityLabel("Progress")
                    .accessibilityValue("\(Int(liveSnapshot.progress * 100)) percent")

                if !liveSnapshot.tags.isEmpty {
                    FlowTagRow(tags: liveSnapshot.tags, limit: 3)
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(liveSnapshot.title)
            .accessibilityValue(CountdownFormatter.accessibilityString(
                remainingSeconds: liveSnapshot.remainingSeconds,
                status: liveSnapshot.status
            ))
        }
    }

    private func rowTime(for snapshot: CountdownSnapshot) -> String {
        if snapshot.status == .expired {
            return "Finished"
        }

        return CountdownFormatter.string(remainingSeconds: snapshot.remainingSeconds, precision: .compact)
    }
}

struct CountdownTagChip: View {
    let title: String
    var systemImage: String?
    var isSelected = false

    var body: some View {
        Label {
            Text(title)
                .lineLimit(1)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .font(.caption)
        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
        .accessibilityLabel(title)
    }
}

struct FlowTagRow: View {
    let tags: [String]
    var limit: Int?

    var body: some View {
        HStack(spacing: 5) {
            ForEach(visibleTags, id: \.self) { tag in
                CountdownTagChip(title: tag, systemImage: "tag")
            }

            if overflowCount > 0 {
                CountdownTagChip(title: "+\(overflowCount)", systemImage: nil)
            }
        }
        .lineLimit(1)
    }

    private var visibleTags: [String] {
        if let limit {
            return Array(tags.prefix(limit))
        }

        return tags
    }

    private var overflowCount: Int {
        guard let limit, tags.count > limit else {
            return 0
        }

        return tags.count - limit
    }
}
