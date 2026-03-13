import AppKit
import Foundation

enum AppearanceMode: Int, CaseIterable {
    case auto = 0
    case light = 1
    case dark = 2

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .auto:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

enum AppearancePreferences {
    private static let modeKey = "appearance.mode"

    static func load(defaults: UserDefaults = .standard) -> AppearanceMode {
        let raw = defaults.integer(forKey: modeKey)
        return AppearanceMode(rawValue: raw) ?? .auto
    }

    static func save(_ mode: AppearanceMode, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: modeKey)
    }

    static func resolvedAppearance(defaults: UserDefaults = .standard) -> NSAppearance? {
        switch load(defaults: defaults) {
        case .auto:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppearanceSettingsModel: ObservableObject {
    @Published var mode: AppearanceMode = .auto
    var onAppearanceApplied: ((NSAppearance?) -> Void)?
    private var systemThemeObserver: NSObjectProtocol?

    init() {
        refresh()
        systemThemeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.mode == .auto {
                self.applyAppearance()
            }
        }
    }

    deinit {
        if let systemThemeObserver {
            DistributedNotificationCenter.default().removeObserver(systemThemeObserver)
        }
    }

    func refresh() {
        mode = AppearancePreferences.load()
    }

    func updateMode(_ newMode: AppearanceMode) {
        mode = newMode
        AppearancePreferences.save(newMode)
        applyAppearance()
    }

    func applyAppearance() {
        let appearance = AppearancePreferences.resolvedAppearance()
        NSApp.appearance = appearance
        onAppearanceApplied?(appearance)
    }
}
