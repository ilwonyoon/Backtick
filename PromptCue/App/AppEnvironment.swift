import Foundation

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

    var shouldOpenCaptureOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_CAPTURE_ON_START")
    }

    var isExecutionMapEnabled: Bool {
        boolFlag("PROMPTCUE_ENABLE_MCP")
    }

    var shouldOpenExecutionMapOnStart: Bool {
        boolFlag("PROMPTCUE_OPEN_MCP_ON_START")
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
