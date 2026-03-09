import AppKit
import Foundation

@MainActor
final class ScreenshotSettingsModel: ObservableObject {
    @Published private(set) var accessState: ScreenshotFolderAccessState = .notConfigured

    init() {
        refresh()
    }

    var suggestedSystemPath: String? {
        ScreenshotDirectoryResolver.suggestedDirectoryDisplayPath
    }

    func refresh() {
        accessState = ScreenshotDirectoryResolver.accessState()
    }

    @discardableResult
    func chooseFolder(
        message: String = "Choose the folder Backtick should watch for recent screenshots."
    ) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        panel.message = message
        panel.directoryURL = ScreenshotDirectoryResolver.selectionSeedURL()

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return false
        }

        do {
            try ScreenshotDirectoryResolver.saveAuthorizedDirectory(url)
            refresh()
            return true
        } catch {
            NSApp.presentError(error)
            return false
        }
    }

    func reconnectFolder() {
        _ = chooseFolder()
    }

    func clearFolder() {
        ScreenshotDirectoryResolver.clearAuthorizedDirectory()
        refresh()
    }

    func revealFolderInFinder() {
        ScreenshotDirectoryResolver.withAuthorizedDirectory { directoryURL in
            NSWorkspace.shared.activateFileViewerSelecting([directoryURL])
        }
    }

    func presentOnboardingIfNeeded() {
        guard ScreenshotDirectoryResolver.shouldPresentOnboarding else {
            return
        }

        ScreenshotDirectoryResolver.markOnboardingHandled()
        _ = chooseFolder(
            message: "Select your screenshot folder once to enable automatic screenshot attach. You can change this later in Settings."
        )
    }
}
