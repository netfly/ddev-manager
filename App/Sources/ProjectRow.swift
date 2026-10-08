import SwiftUI
import DDEVKit

struct ProjectRow: View {
    let project: DDEVProject
    let store: ProjectStore
    @State private var showDetails = false

    private var busy: Bool { store.isBusy(project.name) }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color(for: project.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name).font(.system(size: 12, weight: .medium))
                Text("\(project.type) · \(project.status.label)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if busy {
                ProgressView().controlSize(.small)
            } else {
                // Tighter than the default: a row can hold up to five controls, so they get
                // small control size and minimal horizontal padding to stay on one line.
                HStack(spacing: 2) {
                    controls
                }
                .buttonStyle(CompactIconButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contextMenu { contextItems }
    }

    @ViewBuilder private var controls: some View {
        if project.status.isRunning {
            Button { Task { await store.stop(project.name) } } label: { Image(systemName: "stop.fill") }
                .help("Stop")
            Button { Task { await store.restart(project.name) } } label: { Image(systemName: "arrow.clockwise") }
                .help("Restart")
            if let url = project.primaryURL.flatMap(URL.init(string:)) {
                Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "safari") }
                    .help(project.primaryURL ?? "")
            }
            Button { openSSH() } label: { Image(systemName: "terminal") }
                .help("ddev ssh in \(TerminalLauncher.preferred.displayName)")
            if let client = databaseClient {
                Button { Task { await store.openDatabaseClient(client, project: project) } } label: {
                    Image(systemName: "cylinder.split.1x2")
                }
                .help("Open database in \(client.displayName) (ddev \(client.ddevCommand))")
            }
        } else if project.status == .paused {
            Button { Task { await store.start(project.name) } } label: { Image(systemName: "play.fill") }
                .help("Resume")
            Button { Task { await store.stop(project.name) } } label: { Image(systemName: "stop.fill") }
                .help("Stop")
        } else {
            Button { Task { await store.start(project.name) } } label: { Image(systemName: "play.fill") }
                .help("Start")
        }
        Button {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.approot)
        } label: { Image(systemName: "folder") }
            .help("Open \(project.approot) in Finder")
        Button { showDetails.toggle() } label: { Image(systemName: "info.circle") }
            .help("Project details")
            .popover(isPresented: $showDetails, arrowEdge: .trailing) {
                ProjectDetailView(project: project, store: store)
            }
    }

    @ViewBuilder private var contextItems: some View {
        Button("Open project folder") {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.approot)
        }
        Button("Open in Terminal") { openFolderInTerminal() }
        if project.status.isRunning {
            Button("ddev ssh") { openSSH() }
            if let client = databaseClient {
                Button("Open in \(client.displayName)") {
                    Task { await store.openDatabaseClient(client, project: project) }
                }
            }
        }
        if let mailpit = project.mailpitURL.flatMap(URL.init(string:)) {
            Button("Open Mailpit") { NSWorkspace.shared.open(mailpit) }
        }
        Divider()
        Button("Copy URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(project.primaryURL ?? "", forType: .string)
        }
        Text(project.displayPath)
    }

    /// The DB client chosen in Settings, or the first installed one.
    private var databaseClient: DatabaseClient? {
        DatabaseClient.resolve(preference: UserDefaults.standard.string(forKey: SettingsKey.databaseClient))
    }

    /// `ddev ssh` needs an interactive terminal, so it is launched into the preferred terminal
    /// app rather than run through the store's CommandRunner.
    private func openSSH() {
        let terminal = TerminalLauncher.preferred
        let failure = TerminalLauncher.run(
            command: "\(ShellQuote.single(store.ddevExecutablePath)) ssh",
            in: project.approot,
            scriptName: "ssh-\(project.name)"
        )
        store.recordExternalAction(
            label: "ddev ssh for \(project.name) in \(terminal.displayName)",
            failure: failure
        )
    }

    private func openFolderInTerminal() {
        let failure = TerminalLauncher.open(path: project.approot)
        store.recordExternalAction(
            label: "open \(project.name) in \(TerminalLauncher.preferred.displayName)",
            failure: failure
        )
    }

    private func color(for status: DDEVStatus) -> Color {
        switch status {
        case .running: .green
        case .starting: .yellow
        case .paused: .orange
        case .stopped: .secondary
        case .unknown: .red
        }
    }
}
