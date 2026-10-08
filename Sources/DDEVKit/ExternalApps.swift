import Foundation

public enum ShellQuote {
    /// POSIX single-quote escaping for paths/arguments interpolated into a `/bin/sh -c` script.
    public static func single(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// On-host database GUIs ddev can launch for a project. ddev ships a host command per client
/// (`ddev sequelace`, `ddev tableplus`, …) that only exists when the app is installed, so the
/// picker shows what is actually available instead of offering dead commands.
/// See https://docs.ddev.com/en/stable/users/usage/database-management/#database-guis
public enum DatabaseClient: String, CaseIterable, Identifiable, Sendable {
    case sequelAce, tablePlus, tablePro, querious, dbeaver, mysqlWorkbench, phpMyAdmin, adminer

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sequelAce: "Sequel Ace"
        case .tablePlus: "TablePlus"
        case .tablePro: "TablePro"
        case .querious: "Querious"
        case .dbeaver: "DBeaver"
        case .mysqlWorkbench: "MySQL Workbench"
        case .phpMyAdmin: "phpMyAdmin"
        case .adminer: "Adminer"
        }
    }

    /// The `ddev` subcommand that opens this client with the project's database.
    public var ddevCommand: String {
        switch self {
        case .sequelAce: "sequelace"
        case .tablePlus: "tableplus"
        case .tablePro: "tablepro"
        case .querious: "querious"
        case .dbeaver: "dbeaver"
        case .mysqlWorkbench: "mysqlworkbench"
        case .phpMyAdmin: "phpmyadmin"
        case .adminer: "adminer"
        }
    }

    /// App bundles that satisfy this client (mirrors ddev's own `HostBinaryExists` headers).
    /// Empty for the browser-based ones, which are ddev add-ons rather than local apps.
    public var appPaths: [String] {
        switch self {
        case .sequelAce: ["/Applications/Sequel Ace.app"]
        case .tablePlus: ["/Applications/TablePlus.app", "/Applications/Setapp/TablePlus.app"]
        case .tablePro: ["/Applications/TablePro.app"]
        case .querious: ["/Applications/Querious.app"]
        case .dbeaver: ["/Applications/DBeaver.app"]
        case .mysqlWorkbench: ["/Applications/MySQLWorkbench.app"]
        case .phpMyAdmin, .adminer: []
        }
    }

    /// phpMyAdmin/Adminer run in the browser and need `ddev add-on get …` instead of an app.
    public var isBrowserBased: Bool { appPaths.isEmpty }

    /// Extra setup beyond installing the app, surfaced as a hint in Settings.
    public var setupNote: String? {
        switch self {
        case .phpMyAdmin: "needs `ddev add-on get ddev/ddev-phpmyadmin`"
        case .adminer: "needs `ddev add-on get ddev/ddev-adminer`"
        case .mysqlWorkbench:
            "needs `cp ~/.ddev/commands/host/mysqlworkbench.example ~/.ddev/commands/host/mysqlworkbench`"
        default: nil
        }
    }

    public var isInstalled: Bool {
        isBrowserBased || appPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Order used for auto-detection; browser-based clients are excluded because they depend on
    /// a per-project add-on that cannot be detected from an app bundle.
    public static let autoDetectOrder: [DatabaseClient] =
        [.sequelAce, .tablePlus, .tablePro, .querious, .dbeaver, .mysqlWorkbench]

    public static var installed: [DatabaseClient] { allCases.filter(\.isInstalled) }

    /// Resolves a stored preference: a raw value, or nil/"auto"/an uninstalled client → the
    /// first installed client in `autoDetectOrder`.
    public static func resolve(preference: String?) -> DatabaseClient? {
        if let preference, preference != "auto",
           let explicit = DatabaseClient(rawValue: preference) {
            return explicit
        }
        return autoDetectOrder.first(where: \.isInstalled)
    }
}

/// Terminal apps that can be asked to run `ddev ssh`. The app is launched with a generated
/// `.command` script (verified working with Terminal.app and Warp), which is the only mechanism
/// that doesn't need per-app CLI flags.
public struct TerminalApp: Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let appPaths: [String]

    public init(id: String, displayName: String, appPaths: [String]) {
        self.id = id
        self.displayName = displayName
        self.appPaths = appPaths
    }

    public var isInstalled: Bool { appPaths.contains { FileManager.default.fileExists(atPath: $0) } }

    public static let known: [TerminalApp] = [
        TerminalApp(id: "Terminal", displayName: "Terminal",
                    appPaths: ["/System/Applications/Utilities/Terminal.app",
                               "/Applications/Utilities/Terminal.app"]),
        TerminalApp(id: "iTerm", displayName: "iTerm2", appPaths: ["/Applications/iTerm.app"]),
        TerminalApp(id: "Warp", displayName: "Warp", appPaths: ["/Applications/Warp.app"]),
        TerminalApp(id: "Ghostty", displayName: "Ghostty", appPaths: ["/Applications/Ghostty.app"]),
        TerminalApp(id: "kitty", displayName: "kitty", appPaths: ["/Applications/kitty.app"]),
        TerminalApp(id: "Alacritty", displayName: "Alacritty", appPaths: ["/Applications/Alacritty.app"]),
        TerminalApp(id: "WezTerm", displayName: "WezTerm", appPaths: ["/Applications/WezTerm.app"]),
        TerminalApp(id: "Hyper", displayName: "Hyper", appPaths: ["/Applications/Hyper.app"]),
        TerminalApp(id: "Tabby", displayName: "Tabby", appPaths: ["/Applications/Tabby.app"]),
    ]

    public static var installed: [TerminalApp] { known.filter(\.isInstalled) }

    /// Preference → app. Falls back to the first installed terminal, and finally to
    /// Terminal.app, which ships with macOS.
    public static func resolve(preference: String?) -> TerminalApp {
        if let preference, preference != "auto",
           let explicit = known.first(where: { $0.id == preference }), explicit.isInstalled {
            return explicit
        }
        return installed.first ?? known[0]
    }
}
