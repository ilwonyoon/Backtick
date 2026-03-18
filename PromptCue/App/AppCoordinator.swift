import AppKit
import KeyboardShortcuts
import PromptCueCore

@MainActor
final class AppCoordinator: AppLifecycleCoordinating {
    private struct ExperimentalMCPHTTPLaunchConfiguration: Equatable {
        let port: UInt16
        let authMode: ExperimentalMCPHTTPAuthMode
        let apiKey: String?
        let publicBaseURL: URL?
    }

    let model = AppModel()
    private let hotKeyCenter = HotKeyCenter()
    private let screenshotSettingsModel = ScreenshotSettingsModel()
    private let exportTailSettingsModel = PromptExportTailSettingsModel()
    private let retentionSettingsModel = CardRetentionSettingsModel()
    private let cloudSyncSettingsModel = CloudSyncSettingsModel()
    private let mcpConnectorSettingsModel = MCPConnectorSettingsModel()
    private let environment = AppEnvironment.current
    private lazy var capturePanelController = CapturePanelController(model: model)
    private lazy var stackPanelController = StackPanelController(
        model: model,
        onEditCard: { [weak self] card in
            self?.editCardFromStack(card)
        }
    )
    private lazy var designSystemWindowController = DesignSystemWindowController()
    private lazy var settingsWindowController = SettingsWindowController(
        screenshotSettingsModel: screenshotSettingsModel,
        exportTailSettingsModel: exportTailSettingsModel,
        retentionSettingsModel: retentionSettingsModel,
        cloudSyncSettingsModel: cloudSyncSettingsModel,
        mcpConnectorSettingsModel: mcpConnectorSettingsModel
    )
    private var statusItem: NSStatusItem?
    private var pendingStackToggleTask: Task<Void, Never>?
    private var systemThemeObserver: NSObjectProtocol?
    private var experimentalMCPHTTPSettingsObserver: NSObjectProtocol?
    private var experimentalMCPHTTPProcess: Process?
    private var experimentalMCPHTTPLogPipe: Pipe?
    private var experimentalMCPHTTPRestartWorkItem: DispatchWorkItem?
    private var shouldKeepExperimentalMCPHTTPRunning = false
    private var currentExperimentalMCPHTTPLaunchConfiguration: ExperimentalMCPHTTPLaunchConfiguration?

    private static let experimentalMCPHTTPRestartDelay: TimeInterval = 1

    init() {
        systemThemeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                // Mark controllers immediately so a show() racing with this
                // notification picks up the pending flag even before the
                // dispatched block runs.
                self.stackPanelController.markAppearanceDirty()
                self.capturePanelController.markAppearanceDirty()

                // Defer the actual refresh to the next runloop iteration.
                // The distributed notification arrives *before* AppKit
                // finishes propagating the new effective appearance to
                // windows, so reading effectiveAppearance synchronously
                // returns the stale value and deduplication skips the
                // refresh — the root cause of the recurring regression.
                DispatchQueue.main.async { [weak self] in
                    self?.refreshForInheritedAppearanceChange()

                    // Second pass: "Auto" mode transitions can take longer
                    // for AppKit to resolve the effective appearance. A
                    // delayed retry ensures the panel catches up.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.refreshForInheritedAppearanceChange()
                    }
                }
            }
        }

        experimentalMCPHTTPSettingsObserver = NotificationCenter.default.addObserver(
            forName: .experimentalMCPHTTPSettingsDidChange,
            object: mcpConnectorSettingsModel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncExperimentalMCPHTTPConfiguration()
            }
        }
    }

    deinit {
        if let systemThemeObserver {
            DistributedNotificationCenter.default().removeObserver(systemThemeObserver)
        }
        if let experimentalMCPHTTPSettingsObserver {
            NotificationCenter.default.removeObserver(experimentalMCPHTTPSettingsObserver)
        }
    }

    func start() {
        terminateDuplicateDebugInstancesIfNeeded()
        ScreenshotDirectoryResolver.bootstrapPreferredDirectoryIfNeeded()
        model.start()
        applyCaptureQADraftSeedIfNeeded(environment)
        syncExperimentalMCPHTTPConfiguration()
        hotKeyCenter.registerDefaultShortcuts(
            onCapture: { [weak self] in
                self?.showCapturePanel()
            },
            onToggleStack: { [weak self] in
                self?.toggleStackPanel()
            }
        )
        configureStatusItem()
        screenshotSettingsModel.presentOnboardingIfNeeded()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            self?.stackPanelController.prepareForFirstPresentation()
        }

        if environment.shouldOpenDesignSystemOnStart {
            showDesignSystemWindow()
        }

        if environment.shouldOpenStackOnStart {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                self?.stackPanelController.show()
            }
        }

        if PerformanceTrace.shouldTraceStackToggleOnStart {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: PerformanceTrace.stackToggleDelayNanoseconds)
                self?.toggleStackPanel()
            }
        }

        if environment.shouldOpenSettingsOnStart {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                self?.showSettingsWindow()
            }
        }

        if environment.shouldOpenCaptureOnStart {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                self?.showCapturePanel()
            }
        }
    }

    func stop() {
        pendingStackToggleTask?.cancel()
        pendingStackToggleTask = nil
        stopExperimentalMCPHTTP()
        hotKeyCenter.unregisterAll()
        model.stop()
        statusItem = nil
    }

    func handleCloudRemoteNotification() {
        model.handleCloudRemoteNotification()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = makeStatusItemImage()
        item.button?.imagePosition = .imageOnly
        item.button?.imageScaling = .scaleProportionallyUpOrDown
        item.button?.appearance = nil

        let menu = NSMenu()
        let quickCaptureItem = NSMenuItem(title: "Quick Capture", action: #selector(handleQuickCapture), keyEquivalent: "")
        quickCaptureItem.setShortcut(for: .quickCapture)
        menu.addItem(quickCaptureItem)

        let toggleStackItem = NSMenuItem(title: "Show Stack Panel", action: #selector(handleToggleStack), keyEquivalent: "")
        toggleStackItem.setShortcut(for: .toggleStackPanel)
        menu.addItem(toggleStackItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(handleOpenSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Prompt Cue", action: #selector(handleQuit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func makeStatusItemImage() -> NSImage? {
        if let image = NSImage(named: NSImage.Name("BacktickStatusMark")) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        return NSImage(
            systemSymbolName: "quote.opening",
            accessibilityDescription: "Backtick"
        )
    }

    @objc private func handleQuickCapture() {
        showCapturePanel()
    }

    @objc private func handleToggleStack() {
        toggleStackPanel()
    }

    @objc private func handleOpenSettings() {
        showSettingsWindow()
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }

    private func showCapturePanel() {
        pendingStackToggleTask?.cancel()
        pendingStackToggleTask = nil
        stackPanelController.close()
        capturePanelController.toggle()
    }

    private func editCardFromStack(_ card: CaptureCard) {
        pendingStackToggleTask?.cancel()
        pendingStackToggleTask = nil
        model.beginEditingCaptureCard(card)
        stackPanelController.close(commitDeferredCopies: false)
        capturePanelController.show()
    }

    private func toggleStackPanel() {
        if let pendingStackToggleTask {
            pendingStackToggleTask.cancel()
            self.pendingStackToggleTask = nil
            return
        }
        let shouldMeasureStackOpen = !stackPanelController.isPresentedOrTransitioning

        pendingStackToggleTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer { self.pendingStackToggleTask = nil }

            await self.model.waitForCaptureSubmissionToSettle(
                timeout: AppTiming.captureSubmissionFlushTimeout
            )

            guard !Task.isCancelled else {
                return
            }

            self.capturePanelController.close()
            if self.stackPanelController.isPresentedOrTransitioning {
                self.stackPanelController.close()
            } else {
                if shouldMeasureStackOpen {
                    PerformanceTrace.beginStackOpenTrace()
                }
                self.stackPanelController.show()
            }
        }
    }

    private func showDesignSystemWindow() {
        designSystemWindowController.show()
    }

    private func showSettingsWindow() {
        settingsWindowController.show(selectedTab: startupSettingsTab())
    }

    private func refreshForInheritedAppearanceChange() {
        NSApp.appearance = nil
        NSApp.windows.forEach { window in
            window.appearance = nil
            window.contentView?.appearance = nil
            window.contentViewController?.view.appearance = nil
            window.invalidateShadow()
            window.contentView?.needsDisplay = true
            window.contentViewController?.view.layer?.contents = nil
            window.contentViewController?.view.needsLayout = true
            window.contentViewController?.view.layoutSubtreeIfNeeded()
            window.contentViewController?.view.needsDisplay = true
            window.contentView?.subviews.forEach { $0.needsDisplay = true }
        }

        statusItem?.button?.appearance = nil
        statusItem?.button?.image?.isTemplate = true
        statusItem?.button?.needsDisplay = true

        capturePanelController.refreshForInheritedAppearanceChange()
        stackPanelController.refreshForInheritedAppearanceChange()
        settingsWindowController.refreshForInheritedAppearanceChange()
        designSystemWindowController.refreshForInheritedAppearanceChange()
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

    private func applyCaptureQADraftSeedIfNeeded(_ environment: AppEnvironment) {
        if let directText = environment.qaDraftText {
            model.draftText = directText
            return
        }

        guard let filePath = environment.qaDraftTextFilePath else {
            return
        }

        if let seededText = try? String(contentsOfFile: filePath, encoding: .utf8) {
            model.draftText = seededText
        }
    }

    private func startupSettingsTab() -> SettingsTab? {
        switch environment.startupSettingsTab {
        case .general:
            return .general
        case .capture:
            return .capture
        case .stack:
            return .stack
        case .connectors:
            return .connectors
        case nil:
            return nil
        }
    }

    private func syncExperimentalMCPHTTPConfiguration() {
        guard let desiredConfiguration = desiredExperimentalMCPHTTPLaunchConfiguration() else {
            currentExperimentalMCPHTTPLaunchConfiguration = nil
            mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(.stopped)
            stopExperimentalMCPHTTP()
            return
        }

        let configurationChanged = currentExperimentalMCPHTTPLaunchConfiguration != desiredConfiguration
        currentExperimentalMCPHTTPLaunchConfiguration = desiredConfiguration

        if let process = experimentalMCPHTTPProcess, process.isRunning {
            guard configurationChanged else {
                return
            }

            shouldKeepExperimentalMCPHTTPRunning = true
            experimentalMCPHTTPRestartWorkItem?.cancel()
            experimentalMCPHTTPRestartWorkItem = nil
            mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(.restarting)
            process.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                if process.isRunning {
                    process.interrupt()
                }
            }
            return
        }

        shouldKeepExperimentalMCPHTTPRunning = true
        launchExperimentalMCPHTTPHelper()
    }

    private func launchExperimentalMCPHTTPHelper() {
        guard experimentalMCPHTTPProcess == nil else {
            return
        }

        guard let launchConfiguration = currentExperimentalMCPHTTPLaunchConfiguration
                ?? desiredExperimentalMCPHTTPLaunchConfiguration() else {
            shouldKeepExperimentalMCPHTTPRunning = false
            mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(.stopped)
            return
        }

        if launchConfiguration.authMode == .oauth, launchConfiguration.publicBaseURL == nil {
            shouldKeepExperimentalMCPHTTPRunning = false
            mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(
                .failed("OAuth mode needs a valid public HTTPS URL before Backtick can start the remote server.")
            )
            return
        }

        guard let launchSpec = mcpConnectorSettingsModel.inspection.launchSpec else {
            shouldKeepExperimentalMCPHTTPRunning = false
            mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(
                .failed("Backtick MCP helper launch spec is unavailable.")
            )
            NSLog("Experimental MCP HTTP launch skipped: BacktickMCP helper launch spec unavailable")
            return
        }

        experimentalMCPHTTPRestartWorkItem?.cancel()
        experimentalMCPHTTPRestartWorkItem = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchSpec.command)
        var arguments = launchSpec.arguments + [
            "--transport",
            "http",
            "--host",
            "127.0.0.1",
            "--port",
            "\(launchConfiguration.port)",
            "--auth-mode",
            launchConfiguration.authMode.rawValue,
            "--parent-pid",
            "\(ProcessInfo.processInfo.processIdentifier)",
        ]
        if let apiKey = launchConfiguration.apiKey, launchConfiguration.authMode == .apiKey {
            arguments += ["--api-key", apiKey]
        }
        if let publicBaseURL = launchConfiguration.publicBaseURL {
            arguments += ["--public-base-url", publicBaseURL.absoluteString]
        }
        process.arguments = arguments

        let logPipe = Pipe()
        process.standardOutput = logPipe
        process.standardError = logPipe
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.handleExperimentalMCPHTTPTermination(process)
            }
        }

        beginExperimentalMCPHTTPLogStreaming(from: logPipe)
        mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(.starting)

        do {
            try process.run()
            experimentalMCPHTTPProcess = process
            experimentalMCPHTTPLogPipe = logPipe
            mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(.running)
            NSLog(
                "Experimental MCP HTTP helper started on http://127.0.0.1:%d/mcp",
                Int(launchConfiguration.port)
            )
        } catch {
            logPipe.fileHandleForReading.readabilityHandler = nil
            shouldKeepExperimentalMCPHTTPRunning = false
            mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(
                .failed(error.localizedDescription)
            )
            NSLog("Experimental MCP HTTP helper failed to start: %@", String(describing: error))
        }
    }

    private func stopExperimentalMCPHTTP() {
        shouldKeepExperimentalMCPHTTPRunning = false
        experimentalMCPHTTPRestartWorkItem?.cancel()
        experimentalMCPHTTPRestartWorkItem = nil

        guard let process = experimentalMCPHTTPProcess else {
            return
        }

        experimentalMCPHTTPProcess = nil
        process.terminationHandler = nil
        experimentalMCPHTTPLogPipe?.fileHandleForReading.readabilityHandler = nil
        experimentalMCPHTTPLogPipe = nil
        mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(.stopped)
        guard process.isRunning else {
            return
        }

        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            if process.isRunning {
                process.interrupt()
            }
        }
    }

    private func handleExperimentalMCPHTTPTermination(_ process: Process) {
        NSLog(
            "Experimental MCP HTTP helper exited with status %d",
            process.terminationStatus
        )

        guard experimentalMCPHTTPProcess === process else {
            return
        }

        experimentalMCPHTTPProcess = nil
        experimentalMCPHTTPLogPipe?.fileHandleForReading.readabilityHandler = nil
        experimentalMCPHTTPLogPipe = nil

        guard shouldKeepExperimentalMCPHTTPRunning else {
            mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(.stopped)
            return
        }

        scheduleExperimentalMCPHTTPRestart()
    }

    private func scheduleExperimentalMCPHTTPRestart() {
        experimentalMCPHTTPRestartWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.experimentalMCPHTTPRestartWorkItem = nil
            self.launchExperimentalMCPHTTPHelper()
        }

        experimentalMCPHTTPRestartWorkItem = workItem
        mcpConnectorSettingsModel.setExperimentalRemoteRuntimeState(.restarting)
        NSLog(
            "Experimental MCP HTTP helper restart scheduled in %.1f seconds",
            Self.experimentalMCPHTTPRestartDelay
        )
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.experimentalMCPHTTPRestartDelay,
            execute: workItem
        )
    }

    private func beginExperimentalMCPHTTPLogStreaming(from pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !chunk.isEmpty else {
                return
            }

            NSLog("Experimental MCP HTTP helper: %@", chunk)
        }
    }

    private func desiredExperimentalMCPHTTPLaunchConfiguration() -> ExperimentalMCPHTTPLaunchConfiguration? {
        if environment.shouldLaunchExperimentalMCPHTTPOnStart {
            return ExperimentalMCPHTTPLaunchConfiguration(
                port: environment.experimentalMCPHTTPPort,
                authMode: .apiKey,
                apiKey: environment.experimentalMCPHTTPAPIKey,
                publicBaseURL: nil
            )
        }

        guard mcpConnectorSettingsModel.experimentalRemoteSettings.isEnabled else {
            return nil
        }

        return ExperimentalMCPHTTPLaunchConfiguration(
            port: mcpConnectorSettingsModel.experimentalRemoteSettings.port,
            authMode: mcpConnectorSettingsModel.experimentalRemoteSettings.authMode,
            apiKey: mcpConnectorSettingsModel.experimentalRemoteSettings.apiKey,
            publicBaseURL: mcpConnectorSettingsModel.experimentalRemotePublicBaseURL
        )
    }
}
