import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
protocol AppUpdateControlling: AnyObject {
    var isEnabled: Bool { get }
    func checkForUpdates()
}

@MainActor
final class SparkleUpdateController: NSObject, AppUpdateControlling {
    private static let laneEnabledInfoKey = "BacktickEnableSparkleUpdates"
    private static let appcastInfoKey = "SUFeedURL"
    private static let publicKeyInfoKey = "SUPublicEDKey"

    let isEnabled: Bool

    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController?
    #endif

    init(bundle: Bundle = .main) {
        let laneEnabled = Self.boolValue(for: Self.laneEnabledInfoKey, in: bundle)
        let appcastURL = Self.trimmedStringValue(for: Self.appcastInfoKey, in: bundle)
        let publicKey = Self.trimmedStringValue(for: Self.publicKeyInfoKey, in: bundle)
        let isConfigured = laneEnabled && appcastURL != nil && publicKey != nil

        self.isEnabled = isConfigured

        #if canImport(Sparkle)
        if isConfigured {
            self.updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            self.updaterController = nil
        }
        #endif

        super.init()
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController?.checkForUpdates(nil)
        #endif
    }

    private static func boolValue(for key: String, in bundle: Bundle) -> Bool {
        let value = bundle.object(forInfoDictionaryKey: key)

        if let boolean = value as? Bool {
            return boolean
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let text = value as? String {
            switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "yes", "true":
                return true
            default:
                return false
            }
        }

        return false
    }

    private static func trimmedStringValue(for key: String, in bundle: Bundle) -> String? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        return value
    }
}
