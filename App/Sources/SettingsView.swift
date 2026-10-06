import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(SettingsKey.ddevPath) private var ddevPath = ""
    @AppStorage(SettingsKey.autoRefreshSeconds) private var autoRefreshSeconds = 15
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            TextField("ddev path (blank = auto-detect)", text: $ddevPath)
                .frame(width: 320)
            Stepper("Auto-refresh every \(autoRefreshSeconds)s",
                    value: $autoRefreshSeconds, in: 5...300, step: 5)
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
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            Text("Changing the ddev path requires restarting the app.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 400)
    }
}
