import SwiftUI
import AppKit

/// Appearance override for the panel and its popovers. `system` follows macOS; the other two
/// pin the app regardless of the system setting.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil = inherit the system appearance.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    static func current(_ defaults: UserDefaults = .standard) -> AppearanceMode {
        AppearanceMode(rawValue: defaults.string(forKey: SettingsKey.appearance) ?? "") ?? .system
    }

    /// Applied to `NSApp` rather than via `.preferredColorScheme` on a view: the menu bar
    /// panel, every popover, and the Settings window are separate windows, and only the
    /// app-level appearance covers all of them at once.
    @MainActor
    func apply() {
        NSApp.appearance = nsAppearance
    }
}
