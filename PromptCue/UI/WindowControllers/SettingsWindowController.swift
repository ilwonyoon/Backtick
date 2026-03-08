import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let screenshotSettingsModel = ScreenshotSettingsModel()

    func show() {
        let window = window ?? makeWindow()
        screenshotSettingsModel.refresh()
        window.setContentSize(
            NSSize(
                width: AppUIConstants.settingsPanelWidth,
                height: AppUIConstants.settingsPanelHeight
            )
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let frame = NSRect(
            x: 0,
            y: 0,
            width: AppUIConstants.settingsPanelWidth,
            height: AppUIConstants.settingsPanelHeight
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Prompt Cue Settings"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        window.minSize = NSSize(
            width: AppUIConstants.settingsPanelWidth,
            height: AppUIConstants.settingsPanelHeight
        )
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: PromptCueSettingsView(screenshotSettingsModel: screenshotSettingsModel)
        )

        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window else {
            return
        }

        window.orderOut(nil)
    }
}
