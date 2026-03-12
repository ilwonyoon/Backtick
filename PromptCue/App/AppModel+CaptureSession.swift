import AppKit
import Foundation
import PromptCueCore

extension AppModel {
    func beginCaptureSession() {
        prepareDraftMetricsForPresentation()
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        selectedCaptureSuggestedTargetIndex = 0
        isCaptureSuggestedTargetPresentationActive = true
        refreshSuggestedTargetProviderLifecycle()
        refreshAvailableSuggestedTargets()
        ensureRecentScreenshotCoordinatorStarted()
        recentScreenshotCoordinator.prepareForCaptureSession()
        recentScreenshotCoordinator.suspendExpiration()
        syncRecentScreenshotState()
    }

    func prepareCapturePresentation() {
        prepareDraftMetricsForPresentation()
        syncRecentScreenshotState()
    }

    func endCaptureSession() {
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        selectedCaptureSuggestedTargetIndex = 0
        isCaptureSuggestedTargetPresentationActive = false
        refreshSuggestedTargetProviderLifecycle()
        recentScreenshotCoordinator.resumeExpiration()
        recentScreenshotCoordinator.endCaptureSession()
        syncRecentScreenshotState()
    }

    func beginCaptureSubmission(onSuccess: @escaping @MainActor () -> Void = {}) {
        guard captureSubmissionTask == nil else {
            return
        }

        isSubmittingCapture = true

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return false
            }

            defer {
                self.captureSubmissionTask = nil
                self.isSubmittingCapture = false
            }

            let didSubmit = await self.submitCapture()
            if didSubmit {
                onSuccess()
            }
            return didSubmit
        }

        captureSubmissionTask = task
    }

    @discardableResult
    func submitCapture() async -> Bool {
        let managesSubmittingState = !isSubmittingCapture
        if managesSubmittingState {
            isSubmittingCapture = true
        }
        defer {
            if managesSubmittingState {
                isSubmittingCapture = false
            }
        }

        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        var attachment = currentRecentScreenshotAttachment

        if attachment == nil, recentScreenshotState.showsCaptureSlot {
            if let resolvedURL = await recentScreenshotCoordinator.resolveCurrentCaptureAttachment(
                timeout: AppTiming.recentScreenshotSubmitResolveTimeout
            ) {
                attachment = ScreenshotAttachment(path: resolvedURL.path)
            }

            syncRecentScreenshotState()
        }

        guard !trimmed.isEmpty || attachment != nil else {
            return false
        }

        let newCardID = UUID()
        let importedScreenshotPath: String?

        if let attachment {
            let sourceURL = URL(fileURLWithPath: attachment.path)
            do {
                importedScreenshotPath = try ScreenshotDirectoryResolver.withAccessIfNeeded(
                    to: sourceURL
                ) { scopedURL in
                    try attachmentStore.importScreenshot(
                        from: scopedURL,
                        ownerID: newCardID
                    ).path
                }
            } catch {
                logStorageFailure("Screenshot import failed", error: error)
                return false
            }
        } else {
            importedScreenshotPath = nil
        }

        let newCard = CaptureCard(
            id: newCardID,
            text: trimmed.isEmpty ? "Screenshot attached" : trimmed,
            suggestedTarget: effectiveCaptureSuggestedTarget,
            createdAt: Date(),
            screenshotPath: importedScreenshotPath,
            sortOrder: nextTopSortOrder(in: .active)
        )
        let updatedCards = sortedCards(cards + [newCard])

        do {
            try cardStore.upsert(newCard)
            storageErrorMessage = nil
        } catch {
            cleanupImportedAttachment(atPath: importedScreenshotPath)
            logStorageFailure("Card save failed", error: error)
            return false
        }

        cards = updatedCards
        draftText = ""
        draftEditorMetrics = .empty
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        selectedCaptureSuggestedTargetIndex = 0
        if attachment != nil {
            recentScreenshotCoordinator.consumeCurrent()
        }
        syncRecentScreenshotState()
        cloudSyncEngine?.pushLocalChange(card: newCard)
        return true
    }

    func clearDraft() {
        draftText = ""
        draftEditorMetrics = .empty
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        selectedCaptureSuggestedTargetIndex = 0
    }

    func updateDraftEditorMetrics(_ metrics: CaptureEditorMetrics) {
        if draftEditorMetrics != metrics {
            draftEditorMetrics = metrics
        }
    }

    func prepareDraftMetricsForPresentation() {
        let trimmed = draftText.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else {
            if draftEditorMetrics.layoutWidth == 0 {
                draftEditorMetrics = .empty
            }
            return
        }

        let estimatedMetrics = CaptureEditorLayoutCalculator.estimatedMetrics(
            text: draftText,
            viewportWidth: CaptureRuntimeMetrics.editorViewportWidth,
            maxContentHeight: CaptureRuntimeMetrics.editorMaxHeight,
            minimumLineHeight: CaptureRuntimeMetrics.textLineHeight,
            font: NSFont.systemFont(ofSize: PrimitiveTokens.FontSize.capture),
            lineHeight: PrimitiveTokens.LineHeight.capture
        )

        if draftEditorMetrics.layoutWidth == 0 || estimatedMetrics.visibleHeight > draftEditorMetrics.visibleHeight {
            draftEditorMetrics = estimatedMetrics
        }
    }

    func waitForCaptureSubmissionToSettle(timeout: TimeInterval) async {
        if let captureSubmissionTask {
            _ = await captureSubmissionTask.value
            return
        }

        guard timeout > 0 else {
            return
        }

        let deadline = Date().addingTimeInterval(timeout)
        while isSubmittingCapture && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private var currentRecentScreenshotAttachment: ScreenshotAttachment? {
        switch recentScreenshotState {
        case .previewReady(_, let cacheURL, _):
            return ScreenshotAttachment(path: cacheURL.path)
        case .idle, .detected, .expired, .consumed:
            return nil
        }
    }
}
