import Foundation

extension RecentScreenshotCoordinator {
    func applyScanResult(
        _ scanResult: RecentScreenshotScanResult,
        referenceDate: Date
    ) {
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

        let signalCandidate = filteredCandidate(scanResult.signalCandidate, referenceDate: referenceDate)
        let readableCandidate = filteredCandidate(scanResult.readableCandidate, referenceDate: referenceDate)

        if let signalCandidate {
            let session = ensureSession(for: signalCandidate, referenceDate: referenceDate)

            if let readableCandidate, readableCandidate.sourceKey == session.sourceKey {
                updatePreviewIfNeeded(using: readableCandidate, session: session, referenceDate: referenceDate)
            } else {
                state = .detected(sessionID: session.id, detectedAt: session.detectedAt)
            }

            scheduleExpirationIfNeeded(for: session, referenceDate: referenceDate)
            return
        }

        publishCurrentSessionState(referenceDate: referenceDate)
    }

    func updatePreviewIfNeeded(
        using candidate: RecentScreenshotCandidate,
        session: RecentScreenshotSession,
        referenceDate: Date
    ) {
        var nextSession = session
        nextSession.latestIdentityKey = candidate.identityKey
        nextSession.expiresAt = candidateExpirationDate(candidate, referenceDate: referenceDate)

        if let cacheURL = session.cacheURL, session.latestIdentityKey == candidate.identityKey {
            nextSession.cacheURL = cacheURL
            currentSession = nextSession
            state = .previewReady(
                sessionID: nextSession.id,
                cacheURL: cacheURL,
                thumbnailState: .ready
            )
            return
        }

        clearCacheForSession(nextSession)
        nextSession.cacheURL = nil
        currentSession = nextSession
        state = .detected(sessionID: nextSession.id, detectedAt: nextSession.detectedAt)

        if pendingPreviewCacheRequest?.matches(sessionID: nextSession.id, identityKey: candidate.identityKey) == true {
            return
        }

        schedulePreviewCaching(for: candidate, session: nextSession)
    }

    func ensureClipboardSession(
        for clipboardImage: RecentClipboardImage,
        referenceDate: Date
    ) -> RecentScreenshotSession {
        if var currentSession,
           currentSession.sourceKey == clipboardImage.sourceKey || currentSession.sourceKey == nil {
            currentSession.sourceKey = clipboardImage.sourceKey
            currentSession.latestIdentityKey = clipboardImage.identityKey
            currentSession.expiresAt = clipboardImage.detectedAt.addingTimeInterval(maxAge)
            currentSession.cacheURL = clipboardImage.cacheURL
            self.currentSession = currentSession
            return currentSession
        }

        clearCurrentSessionCache()
        invalidateExpirationTimer()

        let session = RecentScreenshotSession(
            id: UUID(),
            sourceKey: clipboardImage.sourceKey,
            latestIdentityKey: clipboardImage.identityKey,
            detectedAt: referenceDate,
            expiresAt: clipboardImage.detectedAt.addingTimeInterval(maxAge),
            cacheURL: clipboardImage.cacheURL
        )

        currentSession = session
        return session
    }

    func filteredCandidate(
        _ candidate: RecentScreenshotCandidate?,
        referenceDate: Date
    ) -> RecentScreenshotCandidate? {
        guard let candidate else {
            return nil
        }

        guard ignoredSourceKeys[candidate.sourceKey, default: .distantPast] <= referenceDate else {
            return nil
        }

        return candidate
    }

    func ensureSession(
        for candidate: RecentScreenshotCandidate,
        referenceDate: Date
    ) -> RecentScreenshotSession {
        if var currentSession,
           currentSession.sourceKey == candidate.sourceKey || currentSession.sourceKey == nil {
            currentSession.sourceKey = candidate.sourceKey
            currentSession.latestIdentityKey = candidate.identityKey
            currentSession.expiresAt = candidateExpirationDate(candidate, referenceDate: referenceDate)
            self.currentSession = currentSession
            return currentSession
        }

        clearCurrentSessionCache()
        invalidateExpirationTimer()

        let session = RecentScreenshotSession(
            id: UUID(),
            sourceKey: candidate.sourceKey,
            latestIdentityKey: candidate.identityKey,
            detectedAt: referenceDate,
            expiresAt: candidateExpirationDate(candidate, referenceDate: referenceDate),
            cacheURL: nil
        )

        currentSession = session
        state = .detected(sessionID: session.id, detectedAt: session.detectedAt)
        return session
    }

    func ensurePendingDetection(referenceDate: Date) {
        if var currentSession {
            guard currentSession.cacheURL == nil else {
                return
            }

            if currentSession.sourceKey == nil {
                currentSession.expiresAt = referenceDate.addingTimeInterval(settleGrace)
                self.currentSession = currentSession
                state = .detected(sessionID: currentSession.id, detectedAt: currentSession.detectedAt)
            }

            return
        }

        let session = RecentScreenshotSession(
            id: UUID(),
            sourceKey: nil,
            latestIdentityKey: nil,
            detectedAt: referenceDate,
            expiresAt: referenceDate.addingTimeInterval(settleGrace),
            cacheURL: nil
        )

        currentSession = session
        state = .detected(sessionID: session.id, detectedAt: session.detectedAt)
    }

    func candidateExpirationDate(
        _ candidate: RecentScreenshotCandidate,
        referenceDate: Date
    ) -> Date {
        let baseDate = candidate.attachment.modifiedAt ?? referenceDate
        let fileAgeExpiration = baseDate.addingTimeInterval(maxAge)
        let detectionExpiration = referenceDate.addingTimeInterval(maxAge)
        return max(fileAgeExpiration, detectionExpiration)
    }

    func publishCurrentSessionState(referenceDate: Date) {
        guard let currentSession else {
            state = .idle
            invalidateExpirationTimer()
            return
        }

        scheduleExpirationIfNeeded(for: currentSession, referenceDate: referenceDate)
        if let cacheURL = currentSession.cacheURL {
            state = .previewReady(
                sessionID: currentSession.id,
                cacheURL: cacheURL,
                thumbnailState: .ready
            )
        } else {
            state = .detected(sessionID: currentSession.id, detectedAt: currentSession.detectedAt)
        }
    }
}
