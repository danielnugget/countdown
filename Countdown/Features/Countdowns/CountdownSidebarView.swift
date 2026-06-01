import CountdownShared
import AppKit
import SwiftUI

struct CountdownFilterSidebarView: View {
    let isShowingOverview: Bool
    let allCount: Int
    let collections: [String]
    let collectionCount: (String) -> Int
    let selectedCollectionName: String?
    let onShowDashboard: () -> Void
    let onShowCountdowns: () -> Void
    let onSelectCollection: (String) -> Void

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

            Section("Library") {
                FilterSidebarRow(
                    title: "Countdowns",
                    systemImage: "calendar",
                    count: allCount,
                    isSelected: !isShowingOverview && selectedCollectionName == nil,
                    action: onShowCountdowns
                )
            }

            if !collections.isEmpty {
                Section("Collections") {
                    ForEach(collections, id: \.self) { collectionName in
                        FilterSidebarRow(
                            title: collectionName,
                            systemImage: "folder",
                            count: collectionCount(collectionName),
                            isSelected: selectedCollectionName.map {
                                CountdownCollectionNormalizer.key(for: $0) == CountdownCollectionNormalizer.key(for: collectionName)
                            } ?? false,
                            action: { onSelectCollection(collectionName) }
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Countdown")
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
    let statusFilter: CountdownStatusFilter
    let selectedTags: [String]
    let selectedCollectionName: String?
    let tags: [String]
    let allCount: Int
    let upcomingCount: Int
    let finishedCount: Int
    let tagCount: (String) -> Int
    let onCreate: () -> Void
    let onSelectStatus: (CountdownStatusFilter) -> Void
    let onSelectTag: (String) -> Void
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

                Menu {
                    Section("Status") {
                        ForEach(CountdownStatusFilter.allCases) { filter in
                            Button {
                                onSelectStatus(filter)
                            } label: {
                                Label(
                                    statusFilterTitle(for: filter),
                                    systemImage: statusFilter == filter && selectedTags.isEmpty ? "checkmark" : statusFilterIcon(for: filter)
                                )
                            }
                        }
                    }

                    if !tags.isEmpty {
                        Section("Tags") {
                            ForEach(tags, id: \.self) { tag in
                                Button {
                                    onSelectTag(tag)
                                } label: {
                                    Label(
                                        "\(tag) (\(tagCount(tag)))",
                                        systemImage: selectedTags.contains(tag) ? "checkmark" : "tag"
                                    )
                                }
                            }
                        }
                    }

                    Section {
                        Button(action: onClearFilters) {
                            Label("Clear Filters", systemImage: "xmark.circle")
                        }
                        .disabled(!hasActiveFilters && searchText.isEmpty)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .symbolVariant(hasActiveFilters ? .fill : .none)
                }
                .buttonStyle(.borderless)
                .help("Filter Countdowns")
                .accessibilityLabel("Filter countdowns")
            }
        }
        .padding(14)
    }

    private var hasActiveFilters: Bool {
        statusFilter != .all || !selectedTags.isEmpty || selectedCollectionName != nil
    }

    private func statusFilterTitle(for filter: CountdownStatusFilter) -> String {
        switch filter {
        case .all:
            "\(filter.title) (\(allCount))"
        case .upcoming:
            "\(filter.title) (\(upcomingCount))"
        case .finished:
            "\(filter.title) (\(finishedCount))"
        }
    }

    private func statusFilterIcon(for filter: CountdownStatusFilter) -> String {
        switch filter {
        case .all:
            "calendar"
        case .upcoming:
            "calendar.badge.clock"
        case .finished:
            "checkmark.circle"
        }
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
