import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable(String)

    var isEnabled: Bool {
        switch self {
        case .enabled, .requiresApproval:
            return true
        case .disabled, .unavailable:
            return false
        }
    }
}

@MainActor
protocol LaunchAtLoginControlling {
    func status() -> LaunchAtLoginStatus
    func setEnabled(_ isEnabled: Bool) throws
}

@MainActor
struct LaunchAtLoginService: LaunchAtLoginControlling {
    private let appServiceProvider: () -> SMAppService

    init(appServiceProvider: @escaping () -> SMAppService = { SMAppService.mainApp }) {
        self.appServiceProvider = appServiceProvider
    }

    func status() -> LaunchAtLoginStatus {
        switch appServiceProvider().status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable("This Backtick build cannot register itself as a login item.")
        @unknown default:
            return .unavailable("Backtick could not read the current login item status.")
        }
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try appServiceProvider().register()
        } else {
            try appServiceProvider().unregister()
        }
    }
}
