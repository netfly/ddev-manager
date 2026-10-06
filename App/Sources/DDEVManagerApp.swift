import SwiftUI
import DDEVKit

@main
struct DDEVManagerApp: App {
    @State private var store: ProjectStore = {
        let path = DDEVService.resolveExecutable(
            override: UserDefaults.standard.string(forKey: SettingsKey.ddevPath)
        ) ?? "/opt/homebrew/bin/ddev"
        let runner = ProcessRunner()
        return ProjectStore(
            service: DDEVService(runner: runner, executablePath: path),
            engineProbe: EngineProbe(runner: runner)
        )
    }()

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            Image(systemName: store.projects.contains { $0.status.isRunning }
                  ? "shippingbox.fill" : "shippingbox")
        }
        .menuBarExtraStyle(.window)   // required: we render a real panel, not a menu

        Settings {
            SettingsView()
        }
    }
}

enum SettingsKey {
    static let ddevPath = "ddevExecutablePath"
    static let autoRefreshSeconds = "autoRefreshSeconds"
}
