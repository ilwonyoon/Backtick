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

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        panel.message = "Choose the folder Prompt Cue should watch for recent screenshots."
        panel.directoryURL = ScreenshotDirectoryResolver.selectionSeedURL()

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return
        }

        do {
            try ScreenshotDirectoryResolver.saveAuthorizedDirectory(url)
            refresh()
        } catch {
            NSApp.presentError(error)
        }
    }

    func reconnectFolder() {
        chooseFolder()
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
}
