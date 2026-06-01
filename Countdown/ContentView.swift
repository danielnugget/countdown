import CountdownShared
import SwiftUI

struct ContentView: View {
    @Environment(CountdownStore.self) private var store
    @State private var editorMode: CountdownEditorMode?
    @State private var systemEventObserver: CountdownSystemEventObserver?

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            CountdownFilterSidebarView(
                isShowingOverview: store.isShowingOverview,
                statusFilter: store.statusFilter,
                selectedTags: store.selectedTags,
                allCount: store.allSnapshots.count,
                upcomingCount: store.upcomingCount,
                finishedCount: store.finishedCount,
                tags: store.availableTags,
                tagCount: { store.count(for: $0) },
                onShowDashboard: {
                    store.showDashboard()
                    Task { await store.refresh() }
                },
                onSelectStatus: { filter in
                    store.setStatusFilter(filter)
                    Task { await store.refresh() }
                },
                onSelectTag: { tag in
                    store.setTagFilter(tag)
                    Task { await store.refresh() }
                },
                onClearFilters: {
                    store.clearFilters()
                    Task { await store.refresh() }
                }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if store.isShowingOverview {
                CountdownDetailContainer(
                    showsDashboard: true,
                    snapshot: nil,
                    dashboardSnapshots: store.allSnapshots,
                    filteredSnapshots: store.snapshots,
                    tags: store.availableTags,
                    upcomingCount: store.upcomingCount,
                    finishedCount: store.finishedCount,
                    precision: store.settings.displayPrecision,
                    onSelect: { store.selectCountdown($0) },
                    onEdit: { snapshot in editorMode = .edit(snapshot) },
                    onDelete: { snapshot in
                        Task { await store.delete(snapshot) }
                    },
                    onCreate: { editorMode = .createDate }
                )
            } else {
                HSplitView {
                    CountdownListView(
                        snapshots: store.snapshots,
                        selection: $store.selectedID,
                        sort: $store.sort,
                        filterTitle: filterTitle,
                        searchText: store.searchText,
                        onCreate: { editorMode = .createDate },
                        onClearFilters: {
                            store.clearFilters()
                            Task { await store.refresh() }
                        }
                    )
                    .frame(minWidth: 300, idealWidth: 360, maxWidth: 460, maxHeight: .infinity)

                    CountdownDetailContainer(
                        showsDashboard: false,
                        snapshot: store.selectedSnapshot,
                        dashboardSnapshots: store.allSnapshots,
                        filteredSnapshots: store.snapshots,
                        tags: store.availableTags,
                        upcomingCount: store.upcomingCount,
                        finishedCount: store.finishedCount,
                        precision: store.settings.displayPrecision,
                        onSelect: { store.selectCountdown($0) },
                        onEdit: { snapshot in editorMode = .edit(snapshot) },
                        onDelete: { snapshot in
                            Task { await store.delete(snapshot) }
                        },
                        onCreate: { editorMode = .createDate }
                    )
                    .frame(minWidth: 480, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search Countdowns")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    editorMode = .createDate
                } label: {
                    Label("New Countdown", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .task {
            await store.refresh()
            store.consumePendingHandoff()
            systemEventObserver = CountdownSystemEventObserver {
                Task { await store.handleSystemTimeChange() }
            }
        }
        .onChange(of: store.searchText) {
            Task { await store.refresh() }
        }
        .onChange(of: store.sort) {
            Task { await store.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownShowNewEditor)) { _ in
            editorMode = .createDate
        }
        .sheet(item: $editorMode) { mode in
            CountdownEditorView(mode: mode) { request in
                Task {
                    await save(request)
                    editorMode = nil
                }
            } onCancel: {
                editorMode = nil
            }
            .environment(store)
        }
        .alert("Countdown Needs Attention", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func save(_ request: CountdownEditorRequest) async {
        switch request.mode {
        case .createDate:
            await store.createCountdown(
                title: request.title,
                targetDate: request.targetDate,
                colorName: request.colorName,
                symbolName: request.symbolName,
                tags: request.tags
            )
        case .edit(let snapshot):
            await store.updateCountdown(
                snapshot,
                title: request.title,
                targetDate: request.targetDate,
                colorName: request.colorName,
                symbolName: request.symbolName,
                tags: request.tags
            )
        }
    }

    private var filterTitle: String {
        if !store.selectedTags.isEmpty {
            return store.selectedTags.joined(separator: ", ")
        }

        switch store.statusFilter {
        case .all:
            return "All Countdowns"
        case .upcoming:
            return "Upcoming"
        case .finished:
            return "Finished"
        }
    }
}

extension Notification.Name {
    static let countdownShowNewEditor = Notification.Name("CountdownShowNewEditor")
}
