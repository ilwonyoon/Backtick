import Foundation

@MainActor
final class RecentScreenshotCoordinator: RecentScreenshotCoordinating {
    var onStateChange: ((RecentScreenshotState) -> Void)?

    var state: RecentScreenshotState = .idle {
        didSet {
            guard state != oldValue else {
                return
            }

            onStateChange?(state)
        }
    }

    private let observer: RecentScreenshotObserving
    private let locator: RecentScreenshotLocating
    private let cache: TransientScreenshotCaching
    let clipboardProvider: RecentClipboardImageProviding
    let maxAge: TimeInterval
    let settleGrace: TimeInterval
    private let now: () -> Date
    private let backgroundWorker: RecentScreenshotBackgroundWorker

    var currentSession: RecentScreenshotSession?
    var ignoredSourceKeys: [String: Date] = [:]
    private var settleTimer: Timer?
    private var settleDeadline: Date?
    private var expirationTimer: Timer?
    var isExpirationSuspended = false
    private var isStarted = false
    private var scanGeneration: UInt64 = 0
    private var previewGeneration: UInt64 = 0
    private var scanInFlight = false
    private var pendingScanReferenceDate: Date?
    var pendingPreviewCacheRequest: PendingPreviewCacheRequest?
    private var isCaptureSessionMonitoringActive = false

    init(
        observer: RecentScreenshotObserving? = nil,
        locator: RecentScreenshotLocating = RecentScreenshotLocator(),
        cache: TransientScreenshotCaching = TransientScreenshotCache(),
        clipboardProvider: RecentClipboardImageProviding? = nil,
        maxAge: TimeInterval = AppTiming.recentScreenshotMaxAge,
        settleGrace: TimeInterval = AppTiming.recentScreenshotPlaceholderGrace,
        now: @escaping () -> Date = Date.init
    ) {
        self.observer = observer ?? RecentScreenshotDirectoryObserver()
        self.locator = locator
        self.cache = cache
        self.clipboardProvider = clipboardProvider ?? RecentClipboardImageMonitor(cache: cache)
        self.maxAge = maxAge
        self.settleGrace = settleGrace
        self.now = now
        self.backgroundWorker = RecentScreenshotBackgroundWorker(locator: locator, cache: cache)
    }

    func start() {
        guard !isStarted else {
            return
        }

        isStarted = true
        observer.onChange = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleObserverChange(event)
            }
        }

        try? cache.clear()
        clipboardProvider.start()
    }

    func stop() {
        guard isStarted else {
            return
        }

        observer.onChange = nil
        observer.stop()
        clipboardProvider.setMonitoringActive(false)
        clipboardProvider.stop()
        isStarted = false
        isCaptureSessionMonitoringActive = false

        settleTimer?.invalidate()
        settleTimer = nil
        settleDeadline = nil
        expirationTimer?.invalidate()
        expirationTimer = nil
        isExpirationSuspended = false
        scanInFlight = false
        pendingScanReferenceDate = nil
        pendingPreviewCacheRequest = nil
        scanGeneration &+= 1
        previewGeneration &+= 1

        clearCurrentSessionCache()
        currentSession = nil
        ignoredSourceKeys.removeAll()
        state = .idle
    }

    func prepareForCaptureSession() {
        setCaptureSessionMonitoringActive(true)
        clipboardProvider.refreshNow()
        refreshState(allowSynchronousSignalProbe: true)
        scheduleSettlePolling()
    }

    func endCaptureSession() {
        guard isStarted else {
            return
        }

        setCaptureSessionMonitoringActive(false)
    }

    func refreshNow() {
        refreshState()
    }

    func suspendExpiration() {
        isExpirationSuspended = true
        invalidateExpirationTimer()
    }

    func resumeExpiration() {
        isExpirationSuspended = false
        guard let currentSession else { return }
        scheduleExpirationIfNeeded(for: currentSession, referenceDate: now())
    }

    func resolveCurrentCaptureAttachment(timeout: TimeInterval) async -> URL? {
        if case .previewReady(_, let cacheURL, _) = state {
            return cacheURL
        }

        guard timeout > 0 else {
            refreshState()
            if case .previewReady(_, let cacheURL, _) = state {
                return cacheURL
            }
            return nil
        }

        refreshState()
        if case .previewReady(_, let cacheURL, _) = state {
            return cacheURL
        }

        let deadline = now().addingTimeInterval(timeout)

        while now() < deadline {
            if case .previewReady(_, let cacheURL, _) = state {
                return cacheURL
            }

            guard state.showsCaptureSlot || scanInFlight || pendingScanReferenceDate != nil else {
                return nil
            }

            let remaining = deadline.timeIntervalSince(now())
            guard remaining > 0 else {
                break
            }

            let sleepInterval = min(remaining, 0.05)
            try? await Task.sleep(nanoseconds: UInt64(sleepInterval * 1_000_000_000))
        }

        refreshState()
        if case .previewReady(_, let cacheURL, _) = state {
            return cacheURL
        }

        return nil
    }

    func consumeCurrent() {
        guard let currentSession else {
            return
        }

        if currentSession.sourceKey?.hasPrefix("clipboard:") == true {
            clipboardProvider.consumeCurrent()
        }
        rememberIgnoredSourceKey(currentSession.sourceKey)
        clearCurrentSessionCache()
        self.currentSession = nil
        pendingPreviewCacheRequest = nil
        invalidateTimers()
        state = .consumed(sessionID: currentSession.id)
    }

    func dismissCurrent() {
        if let currentSession {
            if currentSession.sourceKey?.hasPrefix("clipboard:") == true {
                clipboardProvider.dismissCurrent()
            }
            rememberIgnoredSourceKey(currentSession.sourceKey)
        }

        clearCurrentSessionCache()
        currentSession = nil
        pendingPreviewCacheRequest = nil
        invalidateTimers()
        refreshState()
    }

    private func handleObserverChange(_ event: RecentScreenshotObservationEvent) {
        switch event {
        case .authorizedDirectoryContentsChanged:
            break
        case .authorizedDirectoryConfigurationChanged:
            resetForAuthorizedDirectoryConfigurationChange()
        }

        refreshState()
        scheduleSettlePolling()
    }

    private func setCaptureSessionMonitoringActive(_ isActive: Bool) {
        guard isCaptureSessionMonitoringActive != isActive else {
            return
        }

        isCaptureSessionMonitoringActive = isActive
        clipboardProvider.setMonitoringActive(isActive)

        if isActive {
            observer.start()
            return
        }

        observer.stop()
        pendingScanReferenceDate = nil
        pendingPreviewCacheRequest = nil
        scanGeneration &+= 1
        previewGeneration &+= 1
        scanInFlight = false
        invalidateTimers()
        state = .idle
    }

    private func refreshState(allowSynchronousSignalProbe: Bool = false) {
        let referenceDate = now()
        purgeIgnoredSourceKeys(referenceDate: referenceDate)

        if !isExpirationSuspended,
           let currentSession, referenceDate >= currentSession.expiresAt {
            expireCurrentSession(currentSession)
            return
        }

        if let clipboardImage = clipboardProvider.recentImage(referenceDate: referenceDate, maxAge: maxAge) {
            let session = ensureClipboardSession(for: clipboardImage, referenceDate: referenceDate)
            state = .previewReady(
                sessionID: session.id,
                cacheURL: clipboardImage.cacheURL,
                thumbnailState: .ready
            )
            scheduleExpirationIfNeeded(for: session, referenceDate: referenceDate)
            return
        }

        if allowSynchronousSignalProbe {
            applySynchronousSignalProbe(referenceDate: referenceDate)
        }

        publishCurrentSessionState(referenceDate: referenceDate)
        scheduleAsyncRefresh(referenceDate: referenceDate)
    }

    private func applySynchronousSignalProbe(referenceDate: Date) {
        guard currentSession?.cacheURL == nil else {
            return
        }

        let signalResult = locator.locateRecentScreenshotSignal(
            now: referenceDate,
            maxAge: maxAge
        )
        let signalCandidate = filteredCandidate(
            signalResult.signalCandidate,
            referenceDate: referenceDate
        )

        guard let signalCandidate else {
            return
        }

        let session = ensureSession(for: signalCandidate, referenceDate: referenceDate)
        state = .detected(sessionID: session.id, detectedAt: session.detectedAt)
    }

    private func scheduleSettlePolling() {
        guard settleGrace > 0 else {
            return
        }

        settleDeadline = now().addingTimeInterval(settleGrace)

        guard settleTimer == nil else {
            return
        }

        settleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, self.isStarted else {
                    timer.invalidate()
                    return
                }

                self.refreshState()

                let referenceDate = self.now()
                let shouldStop = (self.settleDeadline.map { referenceDate >= $0 } ?? true)
                    || self.currentSession?.cacheURL != nil

                if shouldStop {
                    timer.invalidate()
                    self.settleTimer = nil
                    self.settleDeadline = nil
                }
            }
        }
    }

    func scheduleExpirationIfNeeded(
        for session: RecentScreenshotSession,
        referenceDate: Date
    ) {
        guard !isExpirationSuspended else { return }

        if referenceDate >= session.expiresAt {
            expireCurrentSession(session)
            return
        }

        let interval = session.expiresAt.timeIntervalSince(referenceDate)
        let currentFireDate = expirationTimer?.fireDate
        if let currentFireDate,
           abs(currentFireDate.timeIntervalSince(session.expiresAt)) < 0.05 {
            return
        }

        invalidateExpirationTimer()
        expirationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isStarted else {
                    return
                }
                self.expireCurrentSessionIfNeeded()
            }
        }
    }

    private func expireCurrentSessionIfNeeded() {
        guard !isExpirationSuspended else { return }

        guard let currentSession else {
            state = .idle
            return
        }

        guard now() >= currentSession.expiresAt else {
            scheduleExpirationIfNeeded(for: currentSession, referenceDate: now())
            return
        }

        expireCurrentSession(currentSession)
    }

    func expireCurrentSession(_ session: RecentScreenshotSession) {
        clearCurrentSessionCache()
        currentSession = nil
        invalidateTimers()
        state = .expired(sessionID: session.id)
    }

    private func rememberIgnoredSourceKey(_ sourceKey: String?) {
        guard let sourceKey else {
            return
        }

        ignoredSourceKeys[sourceKey] = now().addingTimeInterval(maxAge)
    }

    func purgeIgnoredSourceKeys(referenceDate: Date) {
        ignoredSourceKeys = ignoredSourceKeys.filter { _, expirationDate in
            expirationDate > referenceDate
        }
    }

    func clearCurrentSessionCache() {
        guard let cacheURL = currentSession?.cacheURL else {
            return
        }

        try? cache.removeCachedFile(at: cacheURL)
    }

    func clearCacheForSession(_ session: RecentScreenshotSession) {
        guard let cacheURL = session.cacheURL else {
            return
        }

        try? cache.removeCachedFile(at: cacheURL)
    }

    private func invalidateTimers() {
        settleTimer?.invalidate()
        settleTimer = nil
        settleDeadline = nil
        invalidateExpirationTimer()
    }

    func invalidateExpirationTimer() {
        expirationTimer?.invalidate()
        expirationTimer = nil
    }

    private func resetForAuthorizedDirectoryConfigurationChange() {
        clearCurrentSessionCache()
        currentSession = nil
        pendingPreviewCacheRequest = nil
        pendingScanReferenceDate = nil
        scanInFlight = false
        scanGeneration &+= 1
        previewGeneration &+= 1
        ignoredSourceKeys.removeAll()
        invalidateTimers()
        state = .idle
    }

    private func scheduleAsyncRefresh(referenceDate: Date) {
        pendingScanReferenceDate = referenceDate
        guard !scanInFlight else {
            return
        }

        let requestedReferenceDate = pendingScanReferenceDate ?? referenceDate
        pendingScanReferenceDate = nil
        scanInFlight = true
        scanGeneration &+= 1
        let generation = scanGeneration
        let maxAge = self.maxAge
        let worker = backgroundWorker

        Task(priority: .userInitiated) { @MainActor [weak self, requestedReferenceDate, maxAge, generation, worker] in
            guard let self else {
                return
            }

            let scanResult = await worker.locate(now: requestedReferenceDate, maxAge: maxAge)
            self.handleCompletedScan(
                scanResult,
                referenceDate: requestedReferenceDate,
                generation: generation
            )
        }
    }

    private func handleCompletedScan(
        _ scanResult: RecentScreenshotScanResult,
        referenceDate: Date,
        generation: UInt64
    ) {
        guard isStarted else {
            scanInFlight = false
            pendingScanReferenceDate = nil
            return
        }

        guard generation == scanGeneration else {
            finishAsyncRefresh()
            return
        }

        applyScanResult(scanResult, referenceDate: referenceDate)
        finishAsyncRefresh()
    }

    private func finishAsyncRefresh() {
        scanInFlight = false

        if let pendingScanReferenceDate {
            self.pendingScanReferenceDate = nil
            scheduleAsyncRefresh(referenceDate: pendingScanReferenceDate)
        }
    }

    func schedulePreviewCaching(
        for candidate: RecentScreenshotCandidate,
        session: RecentScreenshotSession
    ) {
        previewGeneration &+= 1
        let generation = previewGeneration
        pendingPreviewCacheRequest = PendingPreviewCacheRequest(
            sessionID: session.id,
            identityKey: candidate.identityKey,
            generation: generation
        )
        let worker = backgroundWorker
        let sessionID = session.id

        Task(priority: .utility) { @MainActor [weak self, candidate, sessionID, generation, worker] in
            guard let self else {
                return
            }

            let cacheURL = await worker.cachePreview(for: candidate, sessionID: sessionID)
            self.handleCompletedPreviewCache(
                cacheURL: cacheURL,
                candidate: candidate,
                sessionID: sessionID,
                generation: generation
            )
        }
    }

    private func handleCompletedPreviewCache(
        cacheURL: URL?,
        candidate: RecentScreenshotCandidate,
        sessionID: UUID,
        generation: UInt64
    ) {
        if pendingPreviewCacheRequest?.generation == generation {
            pendingPreviewCacheRequest = nil
        }

        guard isStarted, generation == previewGeneration else {
            if let cacheURL {
                try? cache.removeCachedFile(at: cacheURL)
            }
            return
        }

        guard var currentSession, currentSession.id == sessionID else {
            if let cacheURL {
                try? cache.removeCachedFile(at: cacheURL)
            }
            return
        }

        currentSession.latestIdentityKey = candidate.identityKey
        currentSession.expiresAt = candidateExpirationDate(candidate, referenceDate: now())
        currentSession.cacheURL = cacheURL
        self.currentSession = currentSession

        guard let cacheURL else {
            state = .detected(sessionID: currentSession.id, detectedAt: currentSession.detectedAt)
            return
        }

        state = .previewReady(
            sessionID: currentSession.id,
            cacheURL: cacheURL,
            thumbnailState: .ready
        )
    }
}

struct RecentScreenshotSession {
    let id: UUID
    var sourceKey: String?
    var latestIdentityKey: String?
    let detectedAt: Date
    var expiresAt: Date
    var cacheURL: URL?
}

struct PendingPreviewCacheRequest {
    let sessionID: UUID
    let identityKey: String
    let generation: UInt64

    func matches(sessionID: UUID, identityKey: String) -> Bool {
        self.sessionID == sessionID && self.identityKey == identityKey
    }
}

private actor RecentScreenshotBackgroundWorker {
    private let locator: RecentScreenshotLocating
    private let cache: TransientScreenshotCaching

    init(locator: RecentScreenshotLocating, cache: TransientScreenshotCaching) {
        self.locator = locator
        self.cache = cache
    }

    func locate(now: Date, maxAge: TimeInterval) -> RecentScreenshotScanResult {
        locator.locateRecentScreenshot(now: now, maxAge: maxAge)
    }

    func cachePreview(for candidate: RecentScreenshotCandidate, sessionID: UUID) -> URL? {
        let sourceURL = candidate.fileURL
        return try? ScreenshotDirectoryResolver.withAccessIfNeeded(to: sourceURL) { readableURL in
            try cache.cacheScreenshot(from: readableURL, sessionID: sessionID)
        }
    }
}
