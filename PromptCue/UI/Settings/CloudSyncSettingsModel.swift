import Combine
import Foundation

extension Notification.Name {
    static let cloudSyncDidComplete = Notification.Name("cloudSyncDidComplete")
    static let cloudSyncDidFail = Notification.Name("cloudSyncDidFail")
    static let cloudSyncEnabledChanged = Notification.Name("cloudSyncEnabledChanged")
}

enum CloudSyncPreferences {
    private static let syncEnabledKey = "cloudSync.enabled"

    static func load(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: syncEnabledKey) as? Bool ?? true
    }

    static func save(enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: syncEnabledKey)
    }
}

@MainActor
final class CloudSyncSettingsModel: ObservableObject {
    @Published var isSyncEnabled = true
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var syncError: String?

    private var cancellables = Set<AnyCancellable>()
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    init() {
        refresh()
        observeSyncNotifications()
    }

    func refresh() {
        isSyncEnabled = CloudSyncPreferences.load()
    }

    func updateSyncEnabled(_ isEnabled: Bool) {
        isSyncEnabled = isEnabled
        CloudSyncPreferences.save(enabled: isEnabled)
        NotificationCenter.default.post(
            name: .cloudSyncEnabledChanged,
            object: nil,
            userInfo: ["enabled": isEnabled]
        )
    }

    func updateLastSynced(_ date: Date) {
        lastSyncedAt = date
        syncError = nil
    }

    func updateSyncError(_ message: String) {
        syncError = message
    }

    func clearSyncError() {
        syncError = nil
    }

    private func observeSyncNotifications() {
        NotificationCenter.default.publisher(for: .cloudSyncDidComplete)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateLastSynced(Date())
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cloudSyncDidFail)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let message = notification.userInfo?["message"] as? String ?? "Unknown error"
                self?.updateSyncError(message)
            }
            .store(in: &cancellables)
    }

    var syncStatusText: String {
        if !isSyncEnabled {
            return "Disabled"
        }

        if let error = syncError {
            return "Error: \(error)"
        }

        guard let lastSyncedAt else {
            return "Waiting for first sync…"
        }

        return "Last synced \(Self.relativeFormatter.localizedString(for: lastSyncedAt, relativeTo: Date()))"
    }
}
