import Foundation

extension AppModel {
    var showsRecentScreenshotSlot: Bool {
        switch recentScreenshotState {
        case .detected, .previewReady:
            return true
        case .idle, .expired, .consumed:
            return false
        }
    }

    var showsRecentScreenshotPlaceholder: Bool {
        switch recentScreenshotState {
        case .detected, .previewReady(_, _, .loading):
            return true
        case .idle, .previewReady(_, _, .ready), .expired, .consumed:
            return false
        }
    }

    var recentScreenshotPreviewURL: URL? {
        switch recentScreenshotState {
        case .previewReady(_, let cacheURL, .ready):
            return cacheURL
        case .idle, .detected, .previewReady(_, _, .loading), .expired, .consumed:
            return nil
        }
    }

    func refreshPendingScreenshot() {
        ensureRecentScreenshotCoordinatorStarted()
        recentScreenshotCoordinator.prepareForCaptureSession()
        syncRecentScreenshotState()
    }

    func dismissPendingScreenshot() {
        recentScreenshotCoordinator.dismissCurrent()
        syncRecentScreenshotState()
    }

    func syncRecentScreenshotState() {
        applyRecentScreenshotState(recentScreenshotCoordinator.state)
    }

    func applyRecentScreenshotState(_ state: RecentScreenshotState) {
        recentScreenshotState = state
    }
}
