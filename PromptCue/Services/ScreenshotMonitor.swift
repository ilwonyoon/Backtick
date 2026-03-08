import Darwin
import Foundation
import PromptCueCore
import UniformTypeIdentifiers

@MainActor
final class ScreenshotMonitor {
    var onChange: (() -> Void)?

    private var latestReadableAttachment: ScreenshotAttachment?
    private var latestSignalAttachment: ScreenshotAttachment?
    private var lastDirectoryActivityAt: Date?
    private var monitoredDirectoryURL: URL?
    private var isAccessingSecurityScope = false
    private var directoryFileDescriptor: CInt = -1
    private var directoryEventSource: DispatchSourceFileSystemObject?
    private var temporaryItemsDirectoryURL: URL?
    private var temporaryItemsFileDescriptor: CInt = -1
    private var temporaryItemsEventSource: DispatchSourceFileSystemObject?
    private var settlePollingTimer: Timer?
    private var settlePollingDeadline: Date?

    func startWatching() {
        refreshAuthorizationIfNeeded(force: true)
        refreshTemporaryItemsWatcherIfNeeded(force: true)
        refreshCache()
    }

    func stopWatching() {
        settlePollingTimer?.invalidate()
        settlePollingTimer = nil
        settlePollingDeadline = nil

        directoryEventSource?.setEventHandler {}
        directoryEventSource?.setCancelHandler {}
        directoryEventSource?.cancel()
        directoryEventSource = nil

        if directoryFileDescriptor >= 0 {
            close(directoryFileDescriptor)
            directoryFileDescriptor = -1
        }

        temporaryItemsEventSource?.setEventHandler {}
        temporaryItemsEventSource?.setCancelHandler {}
        temporaryItemsEventSource?.cancel()
        temporaryItemsEventSource = nil

        if temporaryItemsFileDescriptor >= 0 {
            close(temporaryItemsFileDescriptor)
            temporaryItemsFileDescriptor = -1
        }

        if isAccessingSecurityScope, let monitoredDirectoryURL {
            monitoredDirectoryURL.stopAccessingSecurityScopedResource()
        }

        isAccessingSecurityScope = false
        monitoredDirectoryURL = nil
        temporaryItemsDirectoryURL = nil
        latestReadableAttachment = nil
        latestSignalAttachment = nil
        lastDirectoryActivityAt = nil
    }

    func mostRecentScreenshot(maxAge: TimeInterval) -> ScreenshotAttachment? {
        refreshAuthorizationIfNeeded()
        refreshCache()
        return freshestAttachment(latestReadableAttachment, maxAge: maxAge)
    }

    func mostRecentScreenshotSignal(maxAge: TimeInterval) -> ScreenshotAttachment? {
        refreshAuthorizationIfNeeded()
        refreshCache()
        return freshestAttachment(latestSignalAttachment, maxAge: maxAge)
    }

    func hasRecentDirectoryActivity(maxAge: TimeInterval) -> Bool {
        guard let lastDirectoryActivityAt else {
            return false
        }

        return Date().timeIntervalSince(lastDirectoryActivityAt) <= maxAge
    }

    private func refreshAuthorizationIfNeeded(force: Bool = false) {
        let authorizedDirectoryURL = ScreenshotDirectoryResolver.authorizedDirectoryURLForMonitoring()?.standardizedFileURL

        guard force || authorizedDirectoryURL != monitoredDirectoryURL else {
            return
        }

        reconfigureWatcher(for: authorizedDirectoryURL)
    }

    private func refreshTemporaryItemsWatcherIfNeeded(force: Bool = false) {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TemporaryItems", isDirectory: true)
            .standardizedFileURL

        guard force || temporaryDirectoryURL != temporaryItemsDirectoryURL else {
            return
        }

        reconfigureTemporaryItemsWatcher(for: temporaryDirectoryURL)
    }

    private func reconfigureWatcher(for directoryURL: URL?) {
        settlePollingTimer?.invalidate()
        settlePollingTimer = nil
        settlePollingDeadline = nil

        directoryEventSource?.setEventHandler {}
        directoryEventSource?.setCancelHandler {}
        directoryEventSource?.cancel()
        directoryEventSource = nil

        if directoryFileDescriptor >= 0 {
            close(directoryFileDescriptor)
            directoryFileDescriptor = -1
        }

        if isAccessingSecurityScope, let monitoredDirectoryURL {
            monitoredDirectoryURL.stopAccessingSecurityScopedResource()
        }

        isAccessingSecurityScope = false
        monitoredDirectoryURL = directoryURL
        latestReadableAttachment = nil
        latestSignalAttachment = nil
        lastDirectoryActivityAt = nil

        guard let directoryURL else {
            onChange?()
            return
        }

        isAccessingSecurityScope = directoryURL.startAccessingSecurityScopedResource()
        directoryFileDescriptor = open(directoryURL.path, O_EVTONLY)

        guard directoryFileDescriptor >= 0 else {
            onChange?()
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleDirectoryActivity()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self else {
                return
            }

            if self.directoryFileDescriptor >= 0 {
                close(self.directoryFileDescriptor)
                self.directoryFileDescriptor = -1
            }
        }

        directoryEventSource = source
        source.resume()
        onChange?()
    }

    private func reconfigureTemporaryItemsWatcher(for directoryURL: URL?) {
        temporaryItemsEventSource?.setEventHandler {}
        temporaryItemsEventSource?.setCancelHandler {}
        temporaryItemsEventSource?.cancel()
        temporaryItemsEventSource = nil

        if temporaryItemsFileDescriptor >= 0 {
            close(temporaryItemsFileDescriptor)
            temporaryItemsFileDescriptor = -1
        }

        temporaryItemsDirectoryURL = directoryURL

        guard let directoryURL,
              FileManager.default.fileExists(atPath: directoryURL.path) else {
            return
        }

        temporaryItemsFileDescriptor = open(directoryURL.path, O_EVTONLY)

        guard temporaryItemsFileDescriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: temporaryItemsFileDescriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleDirectoryActivity()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self else {
                return
            }

            if self.temporaryItemsFileDescriptor >= 0 {
                close(self.temporaryItemsFileDescriptor)
                self.temporaryItemsFileDescriptor = -1
            }
        }

        temporaryItemsEventSource = source
        source.resume()
    }

    private func handleDirectoryActivity() {
        lastDirectoryActivityAt = Date()
        refreshCache()
        scheduleSettlePolling()
        onChange?()
    }

    private func scheduleSettlePolling() {
        settlePollingDeadline = Date().addingTimeInterval(AppUIConstants.recentScreenshotPlaceholderGrace)

        guard settlePollingTimer == nil else {
            return
        }

        settlePollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }

                self.refreshAuthorizationIfNeeded()
                self.refreshTemporaryItemsWatcherIfNeeded()
                self.refreshCache()
                self.onChange?()

                guard let deadline = self.settlePollingDeadline, Date() < deadline else {
                    timer.invalidate()
                    self.settlePollingTimer = nil
                    self.settlePollingDeadline = nil
                    return
                }
            }
        }
    }

    private func refreshCache() {
        let minimumDate = Date().addingTimeInterval(-AppUIConstants.recentScreenshotMaxAge)
        var signalCandidates: [ScreenshotMatch] = []
        var readableCandidates: [ScreenshotMatch] = []

        if let monitoredDirectoryURL {
            if let signalMatch = newestScreenshot(
                in: monitoredDirectoryURL,
                minimumDate: minimumDate,
                requireReadableContents: false
            ) {
                signalCandidates.append(signalMatch)
            }

            if let readableMatch = newestScreenshot(
                in: monitoredDirectoryURL,
                minimumDate: minimumDate,
                requireReadableContents: true
            ) {
                readableCandidates.append(readableMatch)
            }
        }

        if let tempSignalMatch = newestTemporaryScreenshot(
            minimumDate: minimumDate,
            requireReadableContents: false
        ) {
            signalCandidates.append(tempSignalMatch)
        }

        if let tempReadableMatch = newestTemporaryScreenshot(
            minimumDate: minimumDate,
            requireReadableContents: true
        ) {
            readableCandidates.append(tempReadableMatch)
        }

        latestSignalAttachment = bestMatch(signalCandidates).map {
            ScreenshotAttachment(
                path: $0.url.path,
                modifiedAt: $0.date,
                fileSize: $0.fileSize
            )
        }
        latestReadableAttachment = bestMatch(readableCandidates).map {
            ScreenshotAttachment(
                path: $0.url.path,
                modifiedAt: $0.date,
                fileSize: $0.fileSize
            )
        }
    }

    private func freshestAttachment(
        _ attachment: ScreenshotAttachment?,
        maxAge: TimeInterval
    ) -> ScreenshotAttachment? {
        guard let attachment else {
            return nil
        }

        let referenceDate = attachment.modifiedAt ?? .distantPast
        guard Date().timeIntervalSince(referenceDate) <= maxAge else {
            return nil
        }

        return attachment
    }

    private func newestScreenshot(
        in directoryURL: URL,
        minimumDate: Date,
        requireReadableContents: Bool
    ) -> ScreenshotMatch? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .creationDateKey,
                .contentModificationDateKey,
                .fileSizeKey,
                .isRegularFileKey,
                .isReadableKey,
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        return contents
            .compactMap {
                screenshotMatch(
                    for: $0,
                    minimumDate: minimumDate,
                    requireReadableContents: requireReadableContents
                )
            }
            .max(by: isLowerPriorityMatch)
    }

    private func newestTemporaryScreenshot(
        minimumDate: Date,
        requireReadableContents: Bool
    ) -> ScreenshotMatch? {
        let temporaryItemsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TemporaryItems", isDirectory: true)

        guard let rootContents = try? FileManager.default.contentsOfDirectory(
            at: temporaryItemsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        var candidates: [ScreenshotMatch] = []

        for itemURL in rootContents {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory == true,
               itemURL.lastPathComponent.hasPrefix("NSIRD_screencaptureui"),
               let nestedContents = try? FileManager.default.contentsOfDirectory(
                   at: itemURL,
                   includingPropertiesForKeys: [
                       .creationDateKey,
                       .contentModificationDateKey,
                       .fileSizeKey,
                       .isRegularFileKey,
                       .isReadableKey,
                   ],
                   options: [.skipsHiddenFiles, .skipsPackageDescendants]
               ) {
                candidates.append(
                    contentsOf: nestedContents.compactMap {
                        screenshotMatch(
                            for: $0,
                            minimumDate: minimumDate,
                            requireReadableContents: requireReadableContents
                        )
                    }
                )
                continue
            }

            if let match = screenshotMatch(
                for: itemURL,
                minimumDate: minimumDate,
                requireReadableContents: requireReadableContents
            ) {
                candidates.append(match)
            }
        }

        return bestMatch(candidates)
    }

    private func bestMatch(_ candidates: [ScreenshotMatch]) -> ScreenshotMatch? {
        candidates.max(by: isLowerPriorityMatch)
    }

    private func isLowerPriorityMatch(_ left: ScreenshotMatch, _ right: ScreenshotMatch) -> Bool {
        if left.matchScore == right.matchScore {
            return left.date < right.date
        }

        return left.matchScore < right.matchScore
    }

    private func screenshotMatch(
        for url: URL,
        minimumDate: Date,
        requireReadableContents: Bool
    ) -> ScreenshotMatch? {
        guard isEligibleImage(url, requireReadableContents: requireReadableContents) else {
            return nil
        }

        guard let candidateDate = resourceDate(for: url), candidateDate >= minimumDate else {
            return nil
        }

        let matchScore = screenshotMatchScore(for: url)
        guard matchScore > 0 else {
            return nil
        }

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return ScreenshotMatch(url: url, date: candidateDate, fileSize: fileSize, matchScore: matchScore)
    }

    private func isEligibleImage(_ url: URL, requireReadableContents: Bool) -> Bool {
        let resourceValues = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey, .isReadableKey]
        )
        guard resourceValues?.isRegularFile == true else {
            return false
        }

        if requireReadableContents {
            guard resourceValues?.isReadable != false else {
                return false
            }

            guard (resourceValues?.fileSize ?? 0) > 0 else {
                return false
            }
        }

        let extensionType = UTType(filenameExtension: url.pathExtension)
        return extensionType?.conforms(to: .image) == true
    }

    private func screenshotMatchScore(for url: URL) -> Int {
        let filename = url.deletingPathExtension().lastPathComponent.lowercased()
        let screenshotHints = [
            "screenshot",
            "screen shot",
            "screen_shot",
            "bildschirmfoto",
            "captura de pantalla",
            "스크린샷",
        ]

        if screenshotHints.contains(where: filename.contains) {
            return 2
        }

        return 1
    }

    private func resourceDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
    }
}

private struct ScreenshotMatch {
    let url: URL
    let date: Date
    let fileSize: Int
    let matchScore: Int
}
