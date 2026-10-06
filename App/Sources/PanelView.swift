import SwiftUI
import DDEVKit

struct PanelView: View {
    let store: ProjectStore
    @State private var refreshTask: Task<Void, Never>?
    @State private var searchText = ""
    @State private var showLog = false

    private var filteredProjects: [DDEVProject] {
        let base = searchText.isEmpty
            ? store.projects
            : store.projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return base.sorted { lhs, rhs in
            let l = lhs.status.sortRank, r = rhs.status.sortRank
            return l != r ? l < r : lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if !store.projects.isEmpty {
                searchField
                Divider()
            }
            if filteredProjects.isEmpty {
                ContentUnavailableView(
                    store.isRefreshing ? "Loading…" : (searchText.isEmpty ? "No DDEV projects" : "No matches"),
                    systemImage: "shippingbox"
                )
                .frame(height: 140)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredProjects) { project in
                            ProjectRow(project: project, store: store)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 420)
            }
            if let error = store.lastError {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(8)
            }
            Divider()
            footer
        }
        .frame(width: 380)
        .task { await store.refresh() }
        .onAppear { startAutoRefresh() }
        .onDisappear { refreshTask?.cancel() }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Filter projects…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack {
            EngineBadge(state: store.engine)
            if case .down = store.engine, store.colimaAvailable {
                if store.isBusy("__colima__") {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Start Colima") { Task { await store.startColima() } }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                }
            }
            Spacer()
            if store.isRefreshing { ProgressView().controlSize(.small) }
            Button {
                Task { await store.refresh() }
            } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Refresh")
        }
        .padding(8)
    }

    private var footer: some View {
        HStack {
            Button("Power off all") { Task { await store.poweroffAll() } }
                .disabled(store.isBusy("__all__"))
            Spacer()
            Button("Log") { showLog.toggle() }
                .popover(isPresented: $showLog) { LogView(entries: store.log) }
            SettingsLink { Text("Settings…") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .padding(8)
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        let seconds = max(5, UserDefaults.standard.integer(forKey: SettingsKey.autoRefreshSeconds))
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                if !Task.isCancelled { await store.refresh() }
            }
        }
    }
}
