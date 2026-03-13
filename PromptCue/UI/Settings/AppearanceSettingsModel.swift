import AppKit
import Foundation

// Legacy compatibility shim. Backtick no longer exposes theme overrides and
// always inherits the system appearance, but older code paths and tests still
// reference these names while the migration settles.
enum AppearanceMode: Int, CaseIterable {
    case auto = 0
    case light = 1
    case dark = 2
}

enum AppearancePreferences {
    private static let modeKey = "appearance.mode"

    static func load(defaults: UserDefaults = .standard) -> AppearanceMode {
        if defaults.object(forKey: modeKey) != nil {
            defaults.removeObject(forKey: modeKey)
        }
        return .auto
    }

    static func save(_ mode: AppearanceMode, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: modeKey)
    }

    static func resolvedAppearance(defaults: UserDefaults = .standard) -> NSAppearance? {
        defaults.removeObject(forKey: modeKey)
        return nil
    }
}

@MainActor
final class AppearanceSettingsModel {
    var onAppearanceApplied: ((NSAppearance?) -> Void)?

    func refresh() {}

    func applyAppearance() {
        NSApp.appearance = nil
        onAppearanceApplied?(nil)
    }
}
