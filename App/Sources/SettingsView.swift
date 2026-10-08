import SwiftUI
import ServiceManagement
import DDEVKit

struct SettingsView: View {
    @AppStorage(SettingsKey.ddevPath) private var ddevPath = ""
    @AppStorage(SettingsKey.autoRefreshSeconds) private var autoRefreshSeconds = 15
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.terminalApp) private var terminalApp = "auto"
    @AppStorage(SettingsKey.databaseClient) private var databaseClient = "auto"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    /// Marks clients whose app isn't present, and the two that need a ddev add-on instead.
    private func clientLabel(_ client: DatabaseClient) -> String {
        if client.isBrowserBased { return "\(client.displayName) (ddev add-on)" }
        return client.isInstalled ? client.displayName : "\(client.displayName) (not installed)"
    }

    private var databaseClientHint: String {
        let resolved = DatabaseClient.resolve(preference: databaseClient)
        if let note = resolved?.setupNote {
            return "Opens the project database via `ddev \(resolved!.ddevCommand)` — \(note)."
        }
        if let resolved {
            return "Opens the project database via `ddev \(resolved.ddevCommand)`."
        }
        return "No supported database GUI found. Install Sequel Ace, TablePlus, TablePro, "
            + "Querious, DBeaver, or MySQL Workbench."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("DDEV Manager Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("ddev executable path")
                    .font(.subheadline.weight(.medium))
                TextField("blank = auto-detect", text: $ddevPath)
                    .textFieldStyle(.roundedBorder)
                Text("Changing this requires restarting the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-refresh interval (seconds)")
                    .font(.subheadline.weight(.medium))
                TextField("15", value: $autoRefreshSeconds, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onChange(of: autoRefreshSeconds) { _, newValue in
                        let clamped = min(300, max(5, newValue))
                        if clamped != newValue { autoRefreshSeconds = clamped }
                    }
                Text("How often the panel polls `ddev list` while open. Range 5–300.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Appearance")
                    .font(.subheadline.weight(.medium))
                Picker("", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
                .onChange(of: appearance) { _, _ in
                    AppearanceMode.current().apply()
                }
                Text("Applies to the panel, its popovers, and this window. “System” follows macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Terminal app")
                    .font(.subheadline.weight(.medium))
                Picker("", selection: $terminalApp) {
                    Text("Auto-detect").tag("auto")
                    ForEach(TerminalApp.known) { app in
                        Text(app.isInstalled ? app.displayName : "\(app.displayName) (not installed)")
                            .tag(app.id)
                    }
                }
                .labelsHidden()
                .frame(width: 240)
                Text("Used for “Open in Terminal” and the `ddev ssh` button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Database client")
                    .font(.subheadline.weight(.medium))
                Picker("", selection: $databaseClient) {
                    Text("Auto-detect").tag("auto")
                    ForEach(DatabaseClient.allCases) { client in
                        Text(clientLabel(client)).tag(client.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 240)
                Text(databaseClientHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            enabled ? try SMAppService.mainApp.register()
                                    : try SMAppService.mainApp.unregister()
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
