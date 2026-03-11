import Foundation

enum StartupSettingsTab: String {
    case general
    case capture
    case stack
    case connectors
}

struct AppEnvironment {
    static var current: AppEnvironment {
        AppEnvironment()
    }

    let values: [String: String]

    init(values: [String: String] = ProcessInfo.processInfo.environment) {
        self.values = values
    }

    var shouldOpenDesignSystemOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_DESIGN_SYSTEM")
    }

    var shouldOpenStackOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_STACK_ON_START")
    }

    var shouldOpenSettingsOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_SETTINGS_ON_START")
    }

    var startupSettingsTab: StartupSettingsTab? {
        nonEmptyValue(for: "PROMPTCUE_OPEN_SETTINGS_TAB")
            .map { $0.lowercased() }
            .flatMap(StartupSettingsTab.init(rawValue:))
    }

    var shouldOpenCaptureOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_CAPTURE_ON_START")
    }

    var qaDraftText: String? {
        nonEmptyValue(for: "PROMPTCUE_QA_DRAFT_TEXT")
    }

    var qaDraftTextFilePath: String? {
        nonEmptyValue(for: "PROMPTCUE_QA_DRAFT_TEXT_FILE")
    }

    private func boolFlag(_ key: String) -> Bool {
        values[key] == "1"
    }

    private func nonEmptyValue(for key: String) -> String? {
        guard let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }
}
