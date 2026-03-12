import CloudKit
import Foundation
import PromptCueCore

extension AppModel {
    func pushCopiedCardsToCloudSync(
        _ copiedCards: [CaptureCard],
        forcePerCardDispatch: Bool = false
    ) {
        guard let cloudSyncEngine, !copiedCards.isEmpty else {
            return
        }

        if forcePerCardDispatch || copiedCards.count == 1 {
            for card in copiedCards {
                cloudSyncEngine.pushLocalChange(card: card)
            }
            return
        }

        cloudSyncEngine.pushBatch(cards: copiedCards, deletions: [])
    }

    func startCloudSync(initialFetchMode: CloudSyncInitialFetchMode = .immediate) {
        guard let cloudSyncEngine else { return }
        cloudSyncEngine.delegate = self

        Task {
            await cloudSyncEngine.setup()
            switch initialFetchMode {
            case .immediate:
                cloudSyncEngine.fetchRemoteChanges()
            case .deferred:
                scheduleDeferredCloudSyncFetch()
            }
        }
    }

    func handleCloudRemoteNotification() {
        deferredCloudSyncFetchTask?.cancel()
        deferredCloudSyncFetchTask = nil
        cloudSyncEngine?.handleRemoteNotification()
    }

    func setSyncEnabled(_ enabled: Bool) {
        if enabled, cloudSyncEngine == nil {
            let engine = cloudSyncEngineFactory()
            cloudSyncEngine = engine
            startCloudSync(initialFetchMode: .immediate)
        } else if !enabled {
            stopCloudSyncEngine()
            deferredCloudSyncFetchTask?.cancel()
            deferredCloudSyncFetchTask = nil
        }
    }

    func applyRemoteChanges(_ changes: [SyncChange]) {
        let plan = buildRemoteApplyPlan(changes)
        applyRemoteApplyPlan(plan)
    }

    func scheduleRemoteChangesForApply(_ changes: [SyncChange]) {
        guard !changes.isEmpty else {
            return
        }

        pendingRemoteChanges.append(contentsOf: changes)
        guard remoteApplyTask == nil else {
            return
        }

        remoteApplyTask = Task { @MainActor [weak self] in
            await self?.processPendingRemoteChanges()
        }
    }

    func waitForRemoteApplyToDrain() async {
        while let remoteApplyTask {
            await remoteApplyTask.value
        }
    }

    private func mergeRemoteChange(
        local: CaptureCard?,
        remote: CaptureCard,
        assetURL: URL?
    ) -> CaptureCard {
        let remoteManagedScreenshotPath = ScreenshotAttachmentPersistencePolicy.managedStoredPath(
            from: remote.screenshotPath,
            attachmentStore: attachmentStore
        )

        guard let local else {
            return card(
                remote,
                replacingScreenshotPath: importRemoteScreenshotPathIfNeeded(
                    for: remote,
                    assetURL: assetURL,
                    shouldImport: remoteManagedScreenshotPath == nil
                ) ?? remoteManagedScreenshotPath
            )
        }

        let winner = mergeWinner(local: local, remote: remote)
        let importedRemoteScreenshotPath = importRemoteScreenshotPathIfNeeded(
            for: remote,
            assetURL: assetURL,
            shouldImport: shouldImportRemoteScreenshot(
                local: local,
                remote: remote,
                winner: winner,
                assetURL: assetURL
            )
        )
        return mergeCard(
            local: local,
            remote: remote,
            winner: winner,
            importedRemoteScreenshotPath: importedRemoteScreenshotPath,
            remoteManagedScreenshotPath: remoteManagedScreenshotPath
        )
    }

    private func importRemoteScreenshotPathIfNeeded(
        for card: CaptureCard,
        assetURL: URL?,
        shouldImport: Bool
    ) -> String? {
        guard shouldImport, let assetURL else {
            return nil
        }

        return importRemoteScreenshotPath(for: card, assetURL: assetURL)
    }

    private func shouldImportRemoteScreenshot(
        local: CaptureCard,
        remote: CaptureCard,
        winner: RemoteMergeWinner,
        assetURL: URL?
    ) -> Bool {
        guard ScreenshotAttachmentPersistencePolicy.managedStoredPath(
            from: remote.screenshotPath,
            attachmentStore: attachmentStore
        ) == nil,
              let assetURL,
              FileManager.default.fileExists(atPath: assetURL.path)
        else {
            return false
        }

        switch winner {
        case .local:
            return local.screenshotPath == nil
        case .remote:
            return true
        }
    }

    private func mergeWinner(local: CaptureCard, remote: CaptureCard) -> RemoteMergeWinner {
        switch (local.lastCopiedAt, remote.lastCopiedAt) {
        case (.some(let localDate), .some(let remoteDate)):
            return localDate >= remoteDate ? .local : .remote
        case (.some, .none):
            return .local
        case (.none, .some):
            return .remote
        case (.none, .none):
            return .local
        }
    }

    private func mergeCard(
        local: CaptureCard,
        remote: CaptureCard,
        winner: RemoteMergeWinner,
        importedRemoteScreenshotPath: String?,
        remoteManagedScreenshotPath: String?
    ) -> CaptureCard {
        switch winner {
        case .local:
            return card(
                local,
                replacingScreenshotPath: local.screenshotPath
                    ?? remoteManagedScreenshotPath
                    ?? importedRemoteScreenshotPath
            )
        case .remote:
            return card(
                remote,
                replacingScreenshotPath: importedRemoteScreenshotPath
                    ?? remoteManagedScreenshotPath
                    ?? local.screenshotPath
            )
        }
    }

    private func card(_ card: CaptureCard, replacingScreenshotPath screenshotPath: String?) -> CaptureCard {
        guard screenshotPath != card.screenshotPath else {
            return card
        }

        return CaptureCard(
            id: card.id,
            text: card.text,
            suggestedTarget: card.suggestedTarget,
            createdAt: card.createdAt,
            screenshotPath: screenshotPath,
            lastCopiedAt: card.lastCopiedAt,
            sortOrder: card.sortOrder
        )
    }

    private func processPendingRemoteChanges() async {
        while !Task.isCancelled {
            guard !pendingRemoteChanges.isEmpty else {
                remoteApplyTask = nil
                return
            }

            let changes = pendingRemoteChanges
            pendingRemoteChanges.removeAll()

            guard !Task.isCancelled else {
                remoteApplyTask = nil
                return
            }

            applyRemoteChanges(changes)
        }

        remoteApplyTask = nil
    }

    private func buildRemoteApplyPlan(_ changes: [SyncChange]) -> RemoteApplyPlan {
        let originalCardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        var updatedCardsByID = originalCardsByID
        var changedCardsByID: [UUID: CaptureCard] = [:]
        var removedCardsByID: [UUID: CaptureCard] = [:]
        var deletedIDs: [UUID] = []

        for change in changes {
            switch change {
            case .upsert(let remoteCard, let screenshotAssetURL):
                let mergedCard = mergeRemoteChange(
                    local: updatedCardsByID[remoteCard.id],
                    remote: remoteCard,
                    assetURL: screenshotAssetURL
                )
                updatedCardsByID[mergedCard.id] = mergedCard
                removedCardsByID.removeValue(forKey: mergedCard.id)

                if originalCardsByID[mergedCard.id] != mergedCard {
                    changedCardsByID[mergedCard.id] = mergedCard
                } else {
                    changedCardsByID.removeValue(forKey: mergedCard.id)
                }

            case .delete(let id):
                if let removedCard = updatedCardsByID.removeValue(forKey: id) {
                    removedCardsByID[id] = removedCard
                    if originalCardsByID[id] != nil {
                        deletedIDs.append(id)
                    }
                }
                changedCardsByID.removeValue(forKey: id)
            }
        }

        let sorted = sortedCards(Array(updatedCardsByID.values))
        let survivingIDs = Set(updatedCardsByID.keys)
        return RemoteApplyPlan(
            sortedCards: sorted,
            changedCards: Array(changedCardsByID.values),
            deletedIDs: deletedIDs,
            survivingIDs: survivingIDs,
            removedCards: Array(removedCardsByID.values)
        )
    }

    private func applyRemoteApplyPlan(_ plan: RemoteApplyPlan) {
        if !plan.changedCards.isEmpty || !plan.deletedIDs.isEmpty {
            do {
                try cardStore.apply(upserts: plan.changedCards, deletions: plan.deletedIDs)
                storageErrorMessage = nil
            } catch {
                logStorageFailure("Cloud sync apply failed", error: error)
                return
            }
        }

        cards = plan.sortedCards
        selectedCardIDs.formIntersection(plan.survivingIDs)
        let hadStagedCopiedCards = hasStagedCopiedCards
        stagedCopiedCardIDs.removeAll { plan.survivingIDs.contains($0) == false }
        syncStagedCopyMode()
        if hadStagedCopiedCards, hasStagedCopiedCards {
            _ = syncStagedMultiCopyClipboard()
        }

        if !plan.removedCards.isEmpty {
            cleanupManagedAttachments(
                removedCards: plan.removedCards,
                remainingCards: plan.sortedCards
            )
        }
    }

    private func importRemoteScreenshotPath(for card: CaptureCard, assetURL: URL) -> String? {
        guard FileManager.default.fileExists(atPath: assetURL.path) else {
            return nil
        }

        do {
            let importedURL = try attachmentStore.importScreenshot(
                from: assetURL,
                ownerID: card.id
            )
            return importedURL.path
        } catch {
            logStorageFailure("Remote screenshot import failed", error: error)
            return nil
        }
    }
}

extension AppModel: CloudSyncDelegate {
    func cloudSyncDidComplete(_ engine: CloudSyncEngine) {
        // Observable by CloudSyncSettingsModel via NotificationCenter
        NotificationCenter.default.post(name: .cloudSyncDidComplete, object: nil)
    }

    func cloudSync(_ engine: CloudSyncEngine, didFailWithError message: String) {
        NotificationCenter.default.post(
            name: .cloudSyncDidFail,
            object: nil,
            userInfo: ["message": message]
        )
    }

    func cloudSync(_ engine: CloudSyncEngine, accountStatusChanged status: CloudSyncAccountStatus) {
        NotificationCenter.default.post(
            name: .cloudSyncAccountStatusChanged,
            object: nil,
            userInfo: ["status": status]
        )
    }

    func cloudSync(_ engine: CloudSyncEngine, didReceiveChanges changes: [SyncChange]) {
        scheduleRemoteChangesForApply(changes)
    }
}
