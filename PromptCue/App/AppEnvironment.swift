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
    let arguments: [String]

    init(
        values: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.values = values
        self.arguments = arguments
    }

    var shouldOpenDesignSystemOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_DESIGN_SYSTEM") || hasArgument("--open-design-system")
    }

    var shouldOpenStackOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_STACK_ON_START")
    }

    var shouldOpenSettingsOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_SETTINGS_ON_START") || startupSettingsTab != nil
    }

    var startupSettingsTab: StartupSettingsTab? {
        startupSettingsTabValue
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

    var shouldLaunchExperimentalMCPHTTPOnStart: Bool {
        boolFlag("PROMPTCUE_EXPERIMENTAL_MCP_HTTP_ON_START")
    }

    var experimentalMCPHTTPPort: UInt16 {
        UInt16(intValue(for: "PROMPTCUE_EXPERIMENTAL_MCP_HTTP_PORT") ?? 8321)
    }

    var experimentalMCPHTTPAPIKey: String? {
        nonEmptyValue(for: "PROMPTCUE_EXPERIMENTAL_MCP_HTTP_API_KEY")
    }

    private func boolFlag(_ key: String) -> Bool {
        values[key] == "1"
    }

    private func hasArgument(_ flag: String) -> Bool {
        arguments.contains(flag)
    }

    private var startupSettingsTabValue: String? {
        nonEmptyValue(for: "PROMPTCUE_OPEN_SETTINGS_TAB")
            ?? argumentValue(for: "--open-settings-tab")
    }

    private func nonEmptyValue(for key: String) -> String? {
        guard let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    private func intValue(for key: String) -> Int? {
        guard let value = nonEmptyValue(for: key) else {
            return nil
        }

        return Int(value)
    }

    private func argumentValue(for flag: String) -> String? {
        guard let flagIndex = arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        let value = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        return value
    }
}
