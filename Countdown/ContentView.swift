import CountdownShared
import SwiftUI

struct ContentView: View {
    @Environment(CountdownStore.self) private var store
    @State private var editorMode: CountdownEditorMode?
    @State private var systemEventObserver: CountdownSystemEventObserver?

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            CountdownSidebarView(
                snapshots: store.snapshots,
                selection: $store.selectedID,
                searchText: $store.searchText,
                onCreate: { editorMode = .createDate }
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 320)
        } detail: {
            CountdownDetailContainer(
                snapshot: store.selectedSnapshot,
                onEdit: { snapshot in editorMode = .edit(snapshot) },
                onDelete: { snapshot in
                    Task { await store.delete(snapshot) }
                },
                onCreate: { editorMode = .createDate }
            )
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
                symbolName: request.symbolName
            )
        case .edit(let snapshot):
            await store.updateCountdown(
                snapshot,
                title: request.title,
                targetDate: request.targetDate
            )
        }
    }
}

extension Notification.Name {
    static let countdownShowNewEditor = Notification.Name("CountdownShowNewEditor")
}
