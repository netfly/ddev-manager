import AppKit
import DDEVKit

enum TerminalLauncher {
    /// The terminal app chosen in Settings (or auto-detected).
    static var preferred: TerminalApp {
        TerminalApp.resolve(preference: UserDefaults.standard.string(forKey: SettingsKey.terminalApp))
    }

    /// Opens a folder in the preferred terminal app.
    /// Returns nil on success, an error message otherwise.
    @discardableResult
    static func open(path: String) -> String? {
        launch(arguments: ["-a", preferred.id, path])
    }

    /// Runs a command in the preferred terminal app, in `directory`.
    ///
    /// macOS has no portable "run this in whatever terminal" API, and every terminal has its own
    /// CLI flags, so the command is written to an executable `.command` script and handed to the
    /// app via `open -a` — the one mechanism that works without per-app knowledge (verified with
    /// Terminal.app and Warp). The script is reused per project rather than accumulating temp
    /// files, and must not be deleted right away: the terminal reads it after `open` returns.
    @discardableResult
    static func run(command: String, in directory: String, scriptName: String) -> String? {
        let script = """
        #!/bin/bash
        cd \(ShellQuote.single(directory)) || exit 1
        exec \(command)
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ddevmanager-\(scriptName).command")
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } catch {
            return error.localizedDescription
        }
        return launch(arguments: ["-a", preferred.id, url.path])
    }

    private static func launch(arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        let err = Pipe()
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return error.localizedDescription
        }
        guard process.terminationStatus != 0 else { return nil }
        let message = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "`open \(arguments.joined(separator: " "))` failed" : message
    }
}
