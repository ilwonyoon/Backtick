import AppKit
import Foundation
import PromptCueCore

@MainActor
protocol SuggestedTargetProviding: AnyObject {
    var onChange: (() -> Void)? { get set }
    func start()
    func stop()
    func currentFreshSuggestedTarget(relativeTo date: Date, freshness: TimeInterval) -> CaptureSuggestedTarget?
    func availableSuggestedTargets() -> [CaptureSuggestedTarget]
    func refreshAvailableSuggestedTargets()
}

@MainActor
final class NoopSuggestedTargetProvider: SuggestedTargetProviding {
    var onChange: (() -> Void)?

    func start() {}
    func stop() {}

    func currentFreshSuggestedTarget(relativeTo date: Date, freshness: TimeInterval) -> CaptureSuggestedTarget? {
        nil
    }

    func availableSuggestedTargets() -> [CaptureSuggestedTarget] {
        []
    }

    func refreshAvailableSuggestedTargets() {}
}

private struct SupportedSuggestedApp: Equatable {
    let appName: String
    let bundleIdentifier: String
    let sourceKind: CaptureSuggestedTargetSourceKind
}

private enum SupportedSuggestedApps {
    static let all: [SupportedSuggestedApp] = [
        SupportedSuggestedApp(appName: "Terminal", bundleIdentifier: "com.apple.Terminal", sourceKind: .terminal),
        SupportedSuggestedApp(appName: "iTerm2", bundleIdentifier: "com.googlecode.iterm2", sourceKind: .terminal),
        SupportedSuggestedApp(appName: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92", sourceKind: .ide),
        SupportedSuggestedApp(appName: "Codex", bundleIdentifier: "com.openai.codex", sourceKind: .ide),
        SupportedSuggestedApp(appName: "Antigravity", bundleIdentifier: "com.google.antigravity", sourceKind: .ide),
        SupportedSuggestedApp(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", sourceKind: .ide),
        SupportedSuggestedApp(appName: "VS Code", bundleIdentifier: "com.microsoft.VSCode", sourceKind: .ide),
        SupportedSuggestedApp(appName: "Windsurf", bundleIdentifier: "com.exafunction.windsurf", sourceKind: .ide),
        SupportedSuggestedApp(appName: "Zed", bundleIdentifier: "dev.zed.Zed", sourceKind: .ide),
    ]

    static let byBundleIdentifier = Dictionary(
        uniqueKeysWithValues: all.map { ($0.bundleIdentifier, $0) }
    )

    static func app(for bundleIdentifier: String) -> SupportedSuggestedApp? {
        byBundleIdentifier[bundleIdentifier]
    }
}

@MainActor
final class RecentSuggestedAppTargetTracker: SuggestedTargetProviding {
    var onChange: (() -> Void)?

    private var activationObserver: NSObjectProtocol?
    private var latestTarget: CaptureSuggestedTarget?
    private var availableTargets: [CaptureSuggestedTarget] = []
    private let resolutionQueue = DispatchQueue(
        label: "com.promptcue.recent-suggested-app-target-resolution",
        qos: .utility
    )
    private var latestResolutionID: UUID?
    private var availableResolutionID: UUID?

    func start() {
        guard activationObserver == nil else {
            return
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleDidActivateApplication(notification)
            }
        }

        if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
            updateLatestTarget(from: frontmostApplication)
        }

        refreshAvailableSuggestedTargets()
    }

    func stop() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }

        activationObserver = nil
    }

    func currentFreshSuggestedTarget(
        relativeTo date: Date = Date(),
        freshness: TimeInterval
    ) -> CaptureSuggestedTarget? {
        guard let latestTarget,
              latestTarget.isFresh(relativeTo: date, freshness: freshness) else {
            return nil
        }

        return latestTarget
    }

    func availableSuggestedTargets() -> [CaptureSuggestedTarget] {
        availableTargets
    }

    func refreshAvailableSuggestedTargets() {
        let resolutionID = UUID()
        availableResolutionID = resolutionID
        let latestTarget = latestTarget

        resolutionQueue.async { [weak self, latestTarget] in
            let enumeratedTargets = enumerateAvailableSuggestedTargets(latestTarget: latestTarget)

            DispatchQueue.main.async { [weak self] in
                guard let self, self.availableResolutionID == resolutionID else {
                    return
                }

                self.availableTargets = enumeratedTargets
                self.onChange?()
            }
        }
    }

    private func handleDidActivateApplication(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        updateLatestTarget(from: application)
    }

    private func updateLatestTarget(from application: NSRunningApplication) {
        guard let bundleIdentifier = application.bundleIdentifier,
              let supportedApp = supportedApp(for: bundleIdentifier) else {
            return
        }

        let capturedAt = Date()
        let windowTitle = frontWindowTitle(forProcessIdentifier: application.processIdentifier)
        let provisionalTarget = CaptureSuggestedTarget(
            appName: supportedApp.appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            capturedAt: capturedAt,
            confidence: .low
        )

        latestTarget = supportedApp.sourceKind == .terminal ? nil : provisionalTarget
        onChange?()
        refreshAvailableSuggestedTargets()

        let resolutionID = UUID()
        latestResolutionID = resolutionID

        resolutionQueue.async { [weak self] in
            let resolvedTarget = buildDetailedSuggestedTarget(
                appName: supportedApp.appName,
                bundleIdentifier: bundleIdentifier,
                fallbackWindowTitle: windowTitle,
                capturedAt: capturedAt
            )

            guard let resolvedTarget else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.latestResolutionID == resolutionID else {
                    return
                }

                self.latestTarget = resolvedTarget
                self.onChange?()
            }
        }
    }

    private func supportedApp(for bundleIdentifier: String) -> SupportedSuggestedApp? {
        SupportedSuggestedApps.app(for: bundleIdentifier)
    }

    private func frontWindowTitle(forProcessIdentifier processIdentifier: pid_t) -> String? {
        windowTitles(forProcessIdentifier: processIdentifier).first
    }
}

private struct TerminalSessionContext {
    let tty: String
    let sessionIdentifier: String?
}

private struct SuggestedTargetWindowSnapshot {
    let appName: String
    let bundleIdentifier: String
    let windowTitle: String?
    let sessionIdentifier: String?
    let tty: String?
}

private struct GitContextSnapshot {
    let repositoryRoot: String
    let repositoryName: String
    let branch: String?
}

private func buildDetailedSuggestedTarget(
    appName: String,
    bundleIdentifier: String,
    fallbackWindowTitle: String?,
    capturedAt: Date,
    sessionContext: TerminalSessionContext? = nil
) -> CaptureSuggestedTarget? {
    let resolvedSessionContext = sessionContext ?? resolveTerminalSessionContext(bundleIdentifier: bundleIdentifier)
    let currentWorkingDirectory = resolvedSessionContext.flatMap { resolveCurrentWorkingDirectory(forTTY: $0.tty) }
    let gitContext = currentWorkingDirectory.flatMap(resolveGitContext(for:))

    return CaptureSuggestedTarget(
        appName: appName,
        bundleIdentifier: bundleIdentifier,
        windowTitle: fallbackWindowTitle,
        sessionIdentifier: resolvedSessionContext?.sessionIdentifier,
        terminalTTY: resolvedSessionContext?.tty,
        currentWorkingDirectory: currentWorkingDirectory,
        repositoryRoot: gitContext?.repositoryRoot,
        repositoryName: gitContext?.repositoryName,
        branch: gitContext?.branch,
        capturedAt: capturedAt,
        confidence: currentWorkingDirectory == nil ? .low : .high
    )
}

private func enumerateAvailableSuggestedTargets(
    latestTarget: CaptureSuggestedTarget?
) -> [CaptureSuggestedTarget] {
    let capturedAt = Date()
    let snapshots = enumerateTerminalWindowSnapshots()
        + enumerateITermWindowSnapshots()
        + enumerateIDEWindowSnapshots()
    var deduplicatedSnapshots: [String: SuggestedTargetWindowSnapshot] = [:]

    for snapshot in snapshots {
        deduplicatedSnapshots[suggestedTargetSnapshotMatchKey(snapshot)] = snapshot
    }

    let targets = deduplicatedSnapshots.values.compactMap { snapshot in
        buildDetailedSuggestedTarget(
            appName: snapshot.appName,
            bundleIdentifier: snapshot.bundleIdentifier,
            fallbackWindowTitle: snapshot.windowTitle,
            capturedAt: capturedAt,
            sessionContext: snapshot.tty.map {
                TerminalSessionContext(
                    tty: $0,
                    sessionIdentifier: snapshot.sessionIdentifier ?? $0
                )
            }
        )
    }

    guard !targets.isEmpty else {
        if let latestTarget {
            return [latestTarget]
        }

        return []
    }

    let latestKey = latestTarget.map(suggestedTargetMatchKey)
    return targets.sorted { lhs, rhs in
        let lhsIsLatest = latestKey == suggestedTargetMatchKey(lhs)
        let rhsIsLatest = latestKey == suggestedTargetMatchKey(rhs)

        if lhsIsLatest != rhsIsLatest {
            return lhsIsLatest
        }

        if lhs.sourceKind != rhs.sourceKind {
            return lhs.sourceKind == .terminal
        }

        if lhs.confidence != rhs.confidence {
            return lhs.confidence == .high
        }

        let appComparison = lhs.appName.localizedCaseInsensitiveCompare(rhs.appName)
        if appComparison != .orderedSame {
            return appComparison == .orderedAscending
        }

        return lhs.workspaceLabel.localizedCaseInsensitiveCompare(rhs.workspaceLabel) == .orderedAscending
    }
}

private func enumerateTerminalWindowSnapshots() -> [SuggestedTargetWindowSnapshot] {
    guard let output = runCommand(
        executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
        arguments: [
            "-e", "tell application \"Terminal\"",
            "-e", "if not running then return \"\"",
            "-e", "set outputText to \"\"",
            "-e", "repeat with w in every window",
            "-e", "set titleText to \"\"",
            "-e", "try",
            "-e", "set titleText to custom title of w",
            "-e", "end try",
            "-e", "if titleText is \"\" then",
            "-e", "try",
            "-e", "set titleText to name of w",
            "-e", "end try",
            "-e", "end if",
            "-e", "set ttyText to \"\"",
            "-e", "try",
            "-e", "set ttyText to tty of selected tab of w",
            "-e", "end try",
            "-e", "if ttyText is not \"\" then",
            "-e", "set outputText to outputText & (id of w as text) & \"|\" & titleText & \"|\" & ttyText & linefeed",
            "-e", "end if",
            "-e", "end repeat",
            "-e", "return outputText",
            "-e", "end tell",
        ]
    ) else {
        return []
    }

    return parseTerminalWindowSnapshotOutput(
        output,
        appName: "Terminal",
        bundleIdentifier: "com.apple.Terminal"
    )
}

private func enumerateITermWindowSnapshots() -> [SuggestedTargetWindowSnapshot] {
    guard let output = runCommand(
        executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
        arguments: [
            "-e", "tell application id \"com.googlecode.iterm2\"",
            "-e", "if not running then return \"\"",
            "-e", "set outputText to \"\"",
            "-e", "repeat with w in windows",
            "-e", "set sessionRef to current session of current tab of w",
            "-e", "set ttyText to \"\"",
            "-e", "set nameText to \"\"",
            "-e", "try",
            "-e", "set ttyText to tty of sessionRef",
            "-e", "end try",
            "-e", "try",
            "-e", "set nameText to name of sessionRef",
            "-e", "end try",
            "-e", "if ttyText is not \"\" then",
            "-e", "set outputText to outputText & (id of w as text) & \"|\" & nameText & \"|\" & ttyText & linefeed",
            "-e", "end if",
            "-e", "end repeat",
            "-e", "return outputText",
            "-e", "end tell",
        ]
    ) else {
        return []
    }

    return parseTerminalWindowSnapshotOutput(
        output,
        appName: "iTerm2",
        bundleIdentifier: "com.googlecode.iterm2"
    )
}

private func parseTerminalWindowSnapshotOutput(
    _ output: String,
    appName: String,
    bundleIdentifier: String
) -> [SuggestedTargetWindowSnapshot] {
    output
        .components(separatedBy: .newlines)
        .compactMap { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else {
                return nil
            }

            let parts = trimmedLine.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else {
                return nil
            }

            let windowID = String(parts[0])
            let windowTitle = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tty = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tty.isEmpty else {
                return nil
            }

            return SuggestedTargetWindowSnapshot(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                windowTitle: windowTitle.isEmpty ? nil : windowTitle,
                sessionIdentifier: windowID,
                tty: tty
            )
        }
}

private func enumerateIDEWindowSnapshots() -> [SuggestedTargetWindowSnapshot] {
    let runningApplications = NSWorkspace.shared.runningApplications
    let supportedIDEs = runningApplications.compactMap { application -> (NSRunningApplication, SupportedSuggestedApp)? in
        guard let bundleIdentifier = application.bundleIdentifier,
              let supportedApp = SupportedSuggestedApps.app(for: bundleIdentifier),
              supportedApp.sourceKind == .ide else {
            return nil
        }

        return (application, supportedApp)
    }

    return supportedIDEs.flatMap { application, supportedApp in
        let titles = windowTitles(forProcessIdentifier: application.processIdentifier)
        let uniqueTitles = Array(NSOrderedSet(array: titles)) as? [String] ?? titles

        if uniqueTitles.isEmpty {
            return [
                SuggestedTargetWindowSnapshot(
                    appName: supportedApp.appName,
                    bundleIdentifier: supportedApp.bundleIdentifier,
                    windowTitle: nil,
                    sessionIdentifier: "\(application.processIdentifier)",
                    tty: nil
                )
            ]
        }

        return uniqueTitles.enumerated().map { index, title in
            SuggestedTargetWindowSnapshot(
                appName: supportedApp.appName,
                bundleIdentifier: supportedApp.bundleIdentifier,
                windowTitle: title,
                sessionIdentifier: "\(application.processIdentifier):\(index)",
                tty: nil
            )
        }
    }
}

private func suggestedTargetMatchKey(_ target: CaptureSuggestedTarget) -> String {
    target.canonicalIdentityKey
}

private func suggestedTargetSnapshotMatchKey(_ snapshot: SuggestedTargetWindowSnapshot) -> String {
    if SupportedSuggestedApps.app(for: snapshot.bundleIdentifier)?.sourceKind == .terminal {
        return [
            snapshot.bundleIdentifier,
            snapshot.tty
                ?? snapshot.sessionIdentifier
                ?? snapshot.windowTitle
                ?? snapshot.appName,
        ]
        .joined(separator: "|")
    }

    return [
        snapshot.bundleIdentifier,
        snapshot.sessionIdentifier ?? "",
        snapshot.windowTitle ?? "",
    ]
    .joined(separator: "|")
}

private func resolveTerminalSessionContext(bundleIdentifier: String) -> TerminalSessionContext? {
    switch bundleIdentifier {
    case "com.apple.Terminal":
        guard let tty = runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: [
                "-e", "tell application \"Terminal\"",
                "-e", "if not running then return \"\"",
                "-e", "return tty of selected tab of front window",
                "-e", "end tell",
            ]
        ) else {
            return nil
        }

        return TerminalSessionContext(tty: tty, sessionIdentifier: tty)

    case "com.googlecode.iterm2":
        guard let output = runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: [
                "-e", "tell application id \"com.googlecode.iterm2\"",
                "-e", "if not running then return \"\"",
                "-e", "tell current session of current window",
                "-e", "set ttyValue to tty",
                "-e", "set sessionName to name",
                "-e", "return ttyValue & linefeed & sessionName",
                "-e", "end tell",
                "-e", "end tell",
            ]
        ) else {
            return nil
        }

        let parts = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let tty = parts.first else {
            return nil
        }

        return TerminalSessionContext(
            tty: tty,
            sessionIdentifier: parts.dropFirst().first
        )

    default:
        return nil
    }
}

private func windowTitles(forProcessIdentifier processIdentifier: pid_t) -> [String] {
    guard let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] else {
        return []
    }

    return windowList.compactMap { window in
        guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
              ownerPID == processIdentifier else {
            return nil
        }

        if let layer = window[kCGWindowLayer as String] as? Int,
           layer != 0 {
            return nil
        }

        guard let title = window[kCGWindowName as String] as? String else {
            return nil
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}

private func resolveCurrentWorkingDirectory(forTTY tty: String) -> String? {
    let ttyName = URL(fileURLWithPath: tty).lastPathComponent
    guard !ttyName.isEmpty,
          let processesOutput = runCommand(
            executableURL: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-t", ttyName, "-o", "pid=,comm="]
          ) else {
        return nil
    }

    let processLines = processesOutput
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    let candidateProcessIDs = processLines.compactMap { line -> String? in
        line.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    for pid in candidateProcessIDs.reversed() {
        if let currentWorkingDirectory = resolveCurrentWorkingDirectory(forProcessID: pid) {
            return currentWorkingDirectory
        }
    }

    return nil
}

private func resolveCurrentWorkingDirectory(forProcessID processID: String) -> String? {
    guard let lsofOutput = runCommand(
        executableURL: URL(fileURLWithPath: "/usr/sbin/lsof"),
        arguments: ["-a", "-p", processID, "-d", "cwd", "-Fn"]
    ) else {
        return nil
    }

    return lsofOutput
        .components(separatedBy: .newlines)
        .first(where: { $0.hasPrefix("n") })
        .map { String($0.dropFirst()) }
}

private func resolveGitContext(for currentWorkingDirectory: String) -> GitContextSnapshot? {
    guard let repositoryRoot = runCommand(
        executableURL: URL(fileURLWithPath: "/usr/bin/git"),
        arguments: ["-C", currentWorkingDirectory, "rev-parse", "--show-toplevel"]
    ) else {
        return nil
    }

    let repositoryName = URL(fileURLWithPath: repositoryRoot).lastPathComponent
    let branch = runCommand(
        executableURL: URL(fileURLWithPath: "/usr/bin/git"),
        arguments: ["-C", currentWorkingDirectory, "branch", "--show-current"]
    )

    return GitContextSnapshot(
        repositoryRoot: repositoryRoot,
        repositoryName: repositoryName,
        branch: branch?.isEmpty == true ? nil : branch
    )
}

private func runCommand(
    executableURL: URL,
    arguments: [String]
) -> String? {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = Pipe()

    do {
        try process.run()
    } catch {
        return nil
    }

    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        return nil
    }

    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
          !output.isEmpty else {
        return nil
    }

    return output
}
