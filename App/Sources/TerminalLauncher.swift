import AppKit

enum TerminalLauncher {
    /// Opens the folder with the user's default terminal app via `open -a`.
    static func open(path: String) {
        let candidates = ["Ghostty", "iTerm", "Warp", "Terminal"]
        for app in candidates {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-a", app, path]
            do { try p.run(); p.waitUntilExit(); if p.terminationStatus == 0 { return } } catch { continue }
        }
    }
}
