import AppKit
import KeyboardShortcuts
import PromptCueCore

@MainActor
final class AppCoordinator {
    private let model = AppModel()
    private let hotKeyCenter = HotKeyCenter()
    private let screenshotSettingsModel = ScreenshotSettingsModel()
    private lazy var capturePanelController = CapturePanelController(model: model)
    private lazy var stackPanelController = StackPanelController(model: model)
    private lazy var designSystemWindowController = DesignSystemWindowController()
    private lazy var settingsWindowController = SettingsWindowController(
        screenshotSettingsModel: screenshotSettingsModel
    )
    private var statusItem: NSStatusItem?

    func start() {
        terminateDuplicateDebugInstancesIfNeeded()
        ScreenshotDirectoryResolver.bootstrapPreferredDirectoryIfNeeded()
        model.start()
        hotKeyCenter.registerDefaultShortcuts(
            onCapture: { [weak self] in
                self?.showCapturePanel()
            },
            onOpenStackView: { [weak self] in
                self?.showStackPanel()
            }
        )
        configureStatusItem()
        screenshotSettingsModel.presentOnboardingIfNeeded()

        if ProcessInfo.processInfo.environment["PROMPTCUE_OPEN_DESIGN_SYSTEM"] == "1" {
            showDesignSystemWindow()
        }

        scheduleAutomationLaunchIfNeeded()
    }

    func stop() {
        hotKeyCenter.unregisterAll()
        model.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "quote.opening", accessibilityDescription: "Prompt Cue")
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        let quickCaptureItem = NSMenuItem(title: "Quick Capture", action: #selector(handleQuickCapture), keyEquivalent: "")
        quickCaptureItem.setShortcut(for: .quickCapture)
        menu.addItem(quickCaptureItem)

        let stackItem = NSMenuItem(title: "Show Stack View", action: #selector(handleOpenStackView), keyEquivalent: "")
        stackItem.setShortcut(for: .openStackView)
        menu.addItem(stackItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Design System…", action: #selector(handleOpenDesignSystem), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(handleOpenSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Prompt Cue", action: #selector(handleQuit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func handleQuickCapture() {
        showCapturePanel()
    }

    @objc private func handleOpenStackView() {
        showStackPanel()
    }

    @objc private func handleOpenSettings() {
        showSettingsWindow()
    }

    @objc private func handleOpenDesignSystem() {
        showDesignSystemWindow()
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }

    private func showCapturePanel() {
        stackPanelController.close()
        capturePanelController.show()
    }

    private func showStackPanel() {
        capturePanelController.close()
        stackPanelController.show()
    }

    private func showDesignSystemWindow() {
        designSystemWindowController.show()
    }

    private func showSettingsWindow() {
        settingsWindowController.show()
    }

    private func scheduleAutomationLaunchIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        let requestedCapture = environment["PROMPTCUE_OPEN_CAPTURE"] == "1"
        let requestedReviewMode = environment["PROMPTCUE_OPEN_REVIEW_MODE"]
            .flatMap(CaptureReviewMode.init(rawValue:))
        let automationDraft = environment["PROMPTCUE_AUTOMATION_DRAFT"]
        let shouldSubmitAutomationDraft = environment["PROMPTCUE_AUTOMATION_SUBMIT_DRAFT"] == "1"

        guard requestedCapture || requestedReviewMode != nil else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else {
                return
            }

            if let requestedReviewMode {
                guard requestedReviewMode == .stack else {
                    return
                }

                self.showStackPanel()
                return
            }

            self.showCapturePanel()

            guard let automationDraft else {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else {
                    return
                }

                self.model.draftText = automationDraft

                guard shouldSubmitAutomationDraft else {
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self else {
                        return
                    }

                    if self.model.submitCapture() {
                        self.capturePanelController.close()
                    }
                }
            }
        }
    }

    private func terminateDuplicateDebugInstancesIfNeeded() {
        #if DEBUG
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let duplicateApps = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentProcessIdentifier }

        for duplicateApp in duplicateApps {
            duplicateApp.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !duplicateApp.isTerminated {
                    duplicateApp.forceTerminate()
                }
            }
        }
        #endif
    }
}
