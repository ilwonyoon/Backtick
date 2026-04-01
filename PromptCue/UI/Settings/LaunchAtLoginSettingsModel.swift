import Foundation

@MainActor
final class LaunchAtLoginSettingsModel: ObservableObject {
    @Published var isEnabled = false
    @Published private(set) var status: LaunchAtLoginStatus = .disabled
    @Published private(set) var lastError: String?

    private let controller: any LaunchAtLoginControlling

    init(controller: (any LaunchAtLoginControlling)? = nil) {
        self.controller = controller ?? LaunchAtLoginService()
        refresh()
    }

    func refresh() {
        let status = controller.status()
        self.status = status
        isEnabled = status.isEnabled
        lastError = nil
    }

    func updateEnabled(_ isEnabled: Bool) {
        let previousStatus = status
        let previousEnabled = self.isEnabled
        lastError = nil
        self.isEnabled = isEnabled

        do {
            try controller.setEnabled(isEnabled)
            refresh()
        } catch {
            status = previousStatus
            self.isEnabled = previousEnabled
            lastError = error.localizedDescription
        }
    }

    var detailText: String {
        if let lastError {
            return lastError
        }

        switch status {
        case .enabled:
            return "Backtick opens automatically when you sign in."
        case .disabled:
            return "Backtick stays off until you launch it manually."
        case .requiresApproval:
            return "Backtick is queued to open at login, but macOS still needs approval in System Settings > General > Login Items."
        case let .unavailable(message):
            return message
        }
    }
}
