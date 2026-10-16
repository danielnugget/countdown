import CountdownShared
import SwiftUI

struct ContentView: View {
    @Environment(CountdownStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var editorMode: CountdownEditorMode?
    @State private var systemEventObserver: CountdownSystemEventObserver?

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            CountdownFilterSidebarView(
                isShowingOverview: store.isShowingOverview,
                allCount: store.allSnapshots.count,
                collections: store.availableCollections,
                collectionCount: { store.count(forCollection: $0) },
                selectedCollectionName: store.selectedCollectionName,
                onShowDashboard: {
                    store.showDashboard()
                },
                onShowCountdowns: {
                    store.clearFilters()
                },
                onSelectCollection: { collectionName in
                    store.setCollectionFilter(collectionName)
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
                        statusFilter: store.statusFilter,
                        selectedTags: store.selectedTags,
                        selectedCollectionName: store.selectedCollectionName,
                        tags: store.availableTags,
                        allCount: store.allSnapshots.count,
                        upcomingCount: store.upcomingCount,
                        finishedCount: store.finishedCount,
                        tagCount: { store.count(for: $0) },
                        onCreate: { editorMode = .createDate },
                        onSelectStatus: { filter in
                            store.setStatusFilter(filter)
                        },
                        onSelectTag: { tag in
                            store.setTagFilter(tag)
                        },
                        onClearFilters: {
                            store.clearFilters()
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
                .accessibilityLabel("New Countdown")
            }
        }
        .task {
            systemEventObserver = CountdownSystemEventObserver(onEvent: {
                Task { await store.handleSystemTimeChange() }
            }, onDataChange: {
                Task { await store.refresh() }
            })
            await store.refresh()
            store.consumePendingHandoff()
            await store.reconcileNotifications()
        }
        .task(id: scenePhase == .active ? store.nextExpirationDate : nil) {
            guard scenePhase == .active, let deadline = store.nextExpirationDate else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                store.advanceClock()
            } catch { /* The view or next deadline changed. */ }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await store.refresh()
                    store.consumePendingHandoff()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownShowNewEditor)) { _ in
            editorMode = .createDate
        }
        .sheet(item: $editorMode) { mode in
            CountdownEditorView(
                mode: mode,
                isSaving: store.isSaving,
                suggestedCollectionName: store.selectedCollectionName,
                collectionSuggestions: store.availableCollections,
                tagSuggestions: store.availableTags
            ) { request in
                Task {
                    if await save(request) { editorMode = nil }
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

    private func save(_ request: CountdownEditorRequest) async -> Bool {
        switch request.mode {
        case .createDate:
            return await store.createCountdown(
                title: request.title,
                targetDate: request.targetDate,
                colorName: request.colorName,
                symbolName: request.symbolName,
                tags: request.tags,
                collectionName: request.collectionName
            )
        case .edit(let snapshot):
            return await store.updateCountdown(
                snapshot,
                title: request.title,
                targetDate: request.targetDate,
                colorName: request.colorName,
                symbolName: request.symbolName,
                tags: request.tags,
                collectionName: request.collectionName
            )
        }
    }

    private var filterTitle: String {
        if let selectedCollectionName = store.selectedCollectionName {
            if !store.selectedTags.isEmpty {
                return "\(selectedCollectionName): \(store.selectedTags.joined(separator: ", "))"
            }

            if store.statusFilter != .all {
                return "\(selectedCollectionName): \(store.statusFilter.title)"
            }

            return selectedCollectionName
        }

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
