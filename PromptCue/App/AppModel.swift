import AppKit
import Combine
import CoreGraphics
import Foundation
import PromptCueCore

struct NotesExportResult: Equatable {
    let noteTitle: String
    let noteIdentifier: String?
}

private enum CaptureSuggestedTargetChoice: Equatable {
    case automatic(CaptureSuggestedTarget)
    case explicit(CaptureSuggestedTarget)

    var target: CaptureSuggestedTarget {
        switch self {
        case .automatic(let target), .explicit(let target):
            return target
        }
    }

    var isAutomatic: Bool {
        if case .automatic = self {
            return true
        }

        return false
    }
}

protocol NotesExporting {
    func exportDailyDigest(cards: [CaptureCard], date: Date) throws -> NotesExportResult
}

enum NotesExportError: LocalizedError {
    case noCards
    case scriptCompilationFailed
    case scriptExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCards:
            return "There are no cards to export."
        case .scriptCompilationFailed:
            return "Notes automation script could not be created."
        case .scriptExecutionFailed(let details):
            return "Notes export failed: \(details)"
        }
    }
}

final class NotesExportService: NotesExporting {
    func exportDailyDigest(cards: [CaptureCard], date: Date = Date()) throws -> NotesExportResult {
        guard !cards.isEmpty else {
            throw NotesExportError.noCards
        }

        let noteTitle = DailyDigestFormatter.noteTitle(for: date)
        let noteBody = DailyDigestFormatter.html(for: cards, date: date)
        let source = """
        set noteTitle to "\(escapeForAppleScript(noteTitle))"
        set noteBody to "\(escapeForAppleScript(noteBody))"
        tell application "Notes"
            set targetAccount to default account
            set targetFolder to default folder of targetAccount
            set matchingNotes to every note of targetFolder whose name is noteTitle
            if (count of matchingNotes) > 0 then
                set targetNote to first item of matchingNotes
                set body of targetNote to noteBody
            else
                set targetNote to make new note at targetFolder with properties {name:noteTitle, body:noteBody}
            end if
            show targetNote separately false
            activate
            return id of targetNote
        end tell
        """

        guard let script = NSAppleScript(source: source) else {
            throw NotesExportError.scriptCompilationFailed
        }

        var executionError: NSDictionary?
        let result = script.executeAndReturnError(&executionError)

        if let executionError {
            throw NotesExportError.scriptExecutionFailed(String(describing: executionError))
        }

        return NotesExportResult(
            noteTitle: noteTitle,
            noteIdentifier: result.stringValue
        )
    }

    private func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var cards: [CaptureCard] = []
    @Published private(set) var storageErrorMessage: String?
    @Published var draftText = ""
    @Published var draftEditorContentHeight: CGFloat = 0
    @Published var pendingScreenshotAttachment: ScreenshotAttachment?
    @Published var isAwaitingRecentScreenshot = false
    @Published private(set) var availableSuggestedTargets: [CaptureSuggestedTarget] = []
    @Published private(set) var captureDebugSuggestedTarget: CaptureSuggestedTarget?
    @Published private(set) var captureDebugSuggestedTargetLine = "No recent terminal"
    @Published var isShowingCaptureSuggestedTargetChooser = false
    @Published private(set) var selectedCaptureSuggestedTargetIndex = 0
    @Published var selectedCardIDs: Set<UUID> = []

    private let cardStore: CardStore
    private let screenshotMonitor: ScreenshotMonitor
    private let attachmentStore: AttachmentStoring
    private let notesExportService: NotesExporting
    private let suggestedTargetProvider: SuggestedTargetProviding
    private var cleanupTimer: Timer?
    private var captureSessionTimer: Timer?
    private var ignoredRecentScreenshotIdentity: String?
    private var pendingScreenshotReservationIdentity: String?
    private var pendingScreenshotReservationDeadline: Date?
    private var draftSuggestedTargetOverride: CaptureSuggestedTarget?

    init(
        cardStore: CardStore,
        screenshotMonitor: ScreenshotMonitor,
        attachmentStore: AttachmentStoring,
        notesExportService: NotesExporting,
        suggestedTargetProvider: SuggestedTargetProviding
    ) {
        self.cardStore = cardStore
        self.screenshotMonitor = screenshotMonitor
        self.attachmentStore = attachmentStore
        self.notesExportService = notesExportService
        self.suggestedTargetProvider = suggestedTargetProvider
        self.suggestedTargetProvider.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.syncAvailableSuggestedTargets()
                self?.refreshSuggestedTargetDebugState()
            }
        }
    }

    convenience init() {
        self.init(
            cardStore: CardStore(),
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(),
            notesExportService: NotesExportService(),
            suggestedTargetProvider: RecentTerminalTargetTracker()
        )
    }

    var selectionCount: Int {
        selectedCardIDs.count
    }

    var selectedCardsInDisplayOrder: [CaptureCard] {
        stackCards.filter { selectedCardIDs.contains($0.id) }
    }

    var stackCards: [CaptureCard] {
        CaptureCardGrouping.stackCards(cards)
    }

    var todayCards: [CaptureCard] {
        let now = Date()
        return stackCards.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: now) }
    }

    var canExportTodayToNotes: Bool {
        !todayCards.isEmpty
    }

    var automaticSuggestedTarget: CaptureSuggestedTarget? {
        suggestedTargetProvider.currentFreshSuggestedTarget(
            relativeTo: Date(),
            freshness: AppUIConstants.suggestedTargetFreshness
        )
    }

    var effectiveCaptureSuggestedTarget: CaptureSuggestedTarget? {
        draftSuggestedTargetOverride ?? automaticSuggestedTarget
    }

    var isCaptureSuggestedTargetAutomatic: Bool {
        draftSuggestedTargetOverride == nil
    }

    var canChooseSuggestedTarget: Bool {
        effectiveCaptureSuggestedTarget != nil || !availableSuggestedTargets.isEmpty
    }

    var captureChooserTarget: CaptureSuggestedTarget? {
        effectiveCaptureSuggestedTarget ?? availableSuggestedTargets.first
    }

    var highlightedCaptureSuggestedTarget: CaptureSuggestedTarget? {
        let choices = captureSuggestedTargetChoices
        guard !choices.isEmpty else {
            return nil
        }

        let clampedIndex = max(0, min(selectedCaptureSuggestedTargetIndex, choices.count - 1))
        return choices[clampedIndex].target
    }

    var isAutomaticCaptureSuggestedTargetHighlighted: Bool {
        let choices = captureSuggestedTargetChoices
        guard !choices.isEmpty else {
            return false
        }

        let clampedIndex = max(0, min(selectedCaptureSuggestedTargetIndex, choices.count - 1))
        return choices[clampedIndex].isAutomatic
    }

    func start() {
        suggestedTargetProvider.start()
        syncAvailableSuggestedTargets()
        refreshSuggestedTargetDebugState()
        screenshotMonitor.onChange = { [weak self] in
            guard let self, self.captureSessionTimer != nil else {
                return
            }

            self.reservePendingScreenshotSlotIfNeeded()
            self.refreshPendingScreenshot()
        }
        screenshotMonitor.startWatching()
        reloadCards()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.purgeExpiredCards()
            }
        }
    }

    func stop() {
        suggestedTargetProvider.stop()
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        captureSessionTimer?.invalidate()
        captureSessionTimer = nil
        screenshotMonitor.onChange = nil
        screenshotMonitor.stopWatching()
    }

    func reloadCards() {
        do {
            cards = sortedCards(try cardStore.load())
            storageErrorMessage = nil
        } catch {
            logStorageFailure("Card load failed", error: error)
            return
        }

        migrateLegacyExternalAttachmentsIfNeeded()
        purgeExpiredCards()
        pruneOrphanedManagedAttachments()
    }

    func beginCaptureSession() {
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        selectedCaptureSuggestedTargetIndex = 0
        refreshAvailableSuggestedTargets()
        refreshSuggestedTargetDebugState()
        screenshotMonitor.startWatching()
        reservePendingScreenshotSlotIfNeeded()
        refreshPendingScreenshot()

        if let captureSessionTimer {
            captureSessionTimer.invalidate()
        }

        captureSessionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reservePendingScreenshotSlotIfNeeded()
                self?.refreshPendingScreenshot()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.captureSessionTimer != nil else {
                    return
                }

                self?.refreshPendingScreenshot()
            }
        }
    }

    func endCaptureSession() {
        captureSessionTimer?.invalidate()
        captureSessionTimer = nil
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        selectedCaptureSuggestedTargetIndex = 0
        clearPendingScreenshotReservation()
    }

    func refreshPendingScreenshot() {
        let candidate = screenshotMonitor.mostRecentScreenshot(maxAge: AppUIConstants.recentScreenshotMaxAge)

        if let candidate {
            guard candidate != pendingScreenshotAttachment else {
                return
            }

            guard candidate.identityKey != ignoredRecentScreenshotIdentity else {
                return
            }

            pendingScreenshotAttachment = candidate
            clearPendingScreenshotReservation()
            return
        }

        guard pendingScreenshotAttachment == nil else {
            return
        }

        if let signal = screenshotMonitor.mostRecentScreenshotSignal(maxAge: AppUIConstants.recentScreenshotMaxAge),
           signal.identityKey != ignoredRecentScreenshotIdentity {
            beginPendingScreenshotReservation(identityKey: signal.identityKey)
            return
        }

        if screenshotMonitor.hasRecentDirectoryActivity(maxAge: AppUIConstants.recentScreenshotPlaceholderGrace) {
            beginPendingScreenshotReservation(identityKey: pendingScreenshotReservationIdentity)
            return
        }

        if let deadline = pendingScreenshotReservationDeadline, Date() >= deadline {
            clearPendingScreenshotReservation()
        }
    }

    @discardableResult
    func submitCapture() -> Bool {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || pendingScreenshotAttachment != nil else {
            return false
        }

        let attachment = pendingScreenshotAttachment
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
            bodyText: trimmed.isEmpty ? "Screenshot attached" : trimmed,
            createdAt: Date(),
            suggestedTarget: effectiveCaptureSuggestedTarget,
            screenshotPath: importedScreenshotPath,
            sortOrder: nextTopSortOrder()
        )
        let updatedCards = sortedCards(cards + [newCard])

        do {
            try cardStore.save(updatedCards)
            storageErrorMessage = nil
        } catch {
            cleanupImportedAttachment(atPath: importedScreenshotPath)
            logStorageFailure("Card save failed", error: error)
            return false
        }

        cards = updatedCards
        draftText = ""
        draftEditorContentHeight = 0
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        selectedCaptureSuggestedTargetIndex = 0
        if let attachment {
            ignoredRecentScreenshotIdentity = attachment.identityKey
        }
        pendingScreenshotAttachment = nil
        clearPendingScreenshotReservation()
        refreshSuggestedTargetDebugState()
        return true
    }

    func clearDraft() {
        draftText = ""
        draftEditorContentHeight = 0
        pendingScreenshotAttachment = nil
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        selectedCaptureSuggestedTargetIndex = 0
        clearPendingScreenshotReservation()
        refreshSuggestedTargetDebugState()
    }

    func dismissPendingScreenshot() {
        if let pendingScreenshotAttachment {
            ignoredRecentScreenshotIdentity = pendingScreenshotAttachment.identityKey
            self.pendingScreenshotAttachment = nil
            clearPendingScreenshotReservation()
            return
        }

        guard let pendingScreenshotReservationIdentity else {
            return
        }

        ignoredRecentScreenshotIdentity = pendingScreenshotReservationIdentity
        clearPendingScreenshotReservation()
    }

    func toggleSelection(for card: CaptureCard) {
        if selectedCardIDs.contains(card.id) {
            selectedCardIDs.remove(card.id)
        } else {
            selectedCardIDs.insert(card.id)
        }
    }

    func clearSelection() {
        selectedCardIDs.removeAll()
    }

    func refreshAvailableSuggestedTargets() {
        suggestedTargetProvider.refreshAvailableSuggestedTargets()
        syncAvailableSuggestedTargets()
        syncCaptureSuggestedTargetSelection()
    }

    func chooseDraftSuggestedTarget(_ target: CaptureSuggestedTarget) {
        draftSuggestedTargetOverride = target
        isShowingCaptureSuggestedTargetChooser = false
        syncCaptureSuggestedTargetSelection()
        refreshSuggestedTargetDebugState()
    }

    func clearDraftSuggestedTargetOverride() {
        draftSuggestedTargetOverride = nil
        isShowingCaptureSuggestedTargetChooser = false
        syncCaptureSuggestedTargetSelection()
        refreshSuggestedTargetDebugState()
    }

    func toggleCaptureSuggestedTargetChooser() {
        if !isShowingCaptureSuggestedTargetChooser {
            refreshAvailableSuggestedTargets()
            syncCaptureSuggestedTargetSelection()
        }

        isShowingCaptureSuggestedTargetChooser.toggle()
    }

    func hideCaptureSuggestedTargetChooser() {
        isShowingCaptureSuggestedTargetChooser = false
    }

    @discardableResult
    func moveCaptureSuggestedTargetSelection(by offset: Int) -> Bool {
        let choices = captureSuggestedTargetChoices
        guard isShowingCaptureSuggestedTargetChooser, !choices.isEmpty else {
            return false
        }

        let count = choices.count
        let current = max(0, min(selectedCaptureSuggestedTargetIndex, count - 1))
        selectedCaptureSuggestedTargetIndex = (current + offset + count) % count
        return true
    }

    @discardableResult
    func highlightCaptureSuggestedTarget(_ target: CaptureSuggestedTarget) -> Bool {
        guard isShowingCaptureSuggestedTargetChooser else {
            return false
        }

        let choices = captureSuggestedTargetChoices
        guard let matchingIndex = choices.firstIndex(where: { !$0.isAutomatic && $0.target == target }) else {
            return false
        }

        selectedCaptureSuggestedTargetIndex = matchingIndex
        return true
    }

    @discardableResult
    func highlightAutomaticCaptureSuggestedTarget() -> Bool {
        guard isShowingCaptureSuggestedTargetChooser else {
            return false
        }

        let choices = captureSuggestedTargetChoices
        guard let matchingIndex = choices.firstIndex(where: \.isAutomatic) else {
            return false
        }

        selectedCaptureSuggestedTargetIndex = matchingIndex
        return true
    }

    @discardableResult
    func completeCaptureSuggestedTargetSelection() -> Bool {
        let choices = captureSuggestedTargetChoices
        guard isShowingCaptureSuggestedTargetChooser, !choices.isEmpty else {
            return false
        }

        let selectedIndex = max(0, min(selectedCaptureSuggestedTargetIndex, choices.count - 1))
        switch choices[selectedIndex] {
        case .automatic:
            clearDraftSuggestedTargetOverride()
        case .explicit(let target):
            chooseDraftSuggestedTarget(target)
        }

        return true
    }

    @discardableResult
    func cancelCaptureSuggestedTargetSelection() -> Bool {
        guard isShowingCaptureSuggestedTargetChooser else {
            return false
        }

        hideCaptureSuggestedTargetChooser()
        return true
    }

    @discardableResult
    func copy(card: CaptureCard) -> String {
        let payload = ClipboardFormatter.string(for: [card])
        ClipboardFormatter.copyToPasteboard(cards: [card])
        markCopied(ids: [card.id])
        return payload
    }

    @discardableResult
    func copySelection() -> String? {
        let selectedCards = selectedCardsInDisplayOrder
        guard !selectedCards.isEmpty else {
            return nil
        }

        let payload = ClipboardFormatter.string(for: selectedCards)
        ClipboardFormatter.copyToPasteboard(cards: selectedCards)
        markCopied(ids: selectedCards.map(\.id))
        return payload
    }

    @discardableResult
    func exportTodayToNotes() -> NotesExportResult? {
        let cardsToExport = todayCards
        guard !cardsToExport.isEmpty else {
            return nil
        }

        do {
            let result = try notesExportService.exportDailyDigest(
                cards: cardsToExport,
                date: Date()
            )
            storageErrorMessage = nil
            return result
        } catch {
            logStorageFailure("Notes export failed", error: error)
            return nil
        }
    }

    func delete(card: CaptureCard) {
        let updatedCards = cards.filter { $0.id != card.id }

        do {
            try cardStore.save(updatedCards)
            storageErrorMessage = nil
        } catch {
            logStorageFailure("Card delete failed", error: error)
            return
        }

        cards = updatedCards
        selectedCardIDs.remove(card.id)
        cleanupManagedAttachments(removedCards: [card], remainingCards: updatedCards)
    }

    func assignSuggestedTarget(_ target: CaptureSuggestedTarget, to card: CaptureCard) {
        let updatedCards = sortedCards(
            cards.map { existingCard in
                guard existingCard.id == card.id else {
                    return existingCard
                }

                return existingCard.updatingSuggestedTarget(target)
            }
        )

        do {
            try cardStore.save(updatedCards)
            storageErrorMessage = nil
        } catch {
            logStorageFailure("Suggested target update failed", error: error)
            return
        }

        cards = updatedCards
    }

    func purgeExpiredCards() {
        let now = Date()
        let expiredCards = cards.filter { $0.isExpired(relativeTo: now) }
        guard !expiredCards.isEmpty else {
            return
        }

        let filtered = sortedCards(cards.filter { !$0.isExpired(relativeTo: now) })

        do {
            try cardStore.save(filtered)
            storageErrorMessage = nil
        } catch {
            logStorageFailure("Card purge failed", error: error)
            return
        }

        cards = filtered
        selectedCardIDs = selectedCardIDs.filter { id in
            filtered.contains(where: { $0.id == id })
        }
        cleanupManagedAttachments(removedCards: expiredCards, remainingCards: filtered)
    }

    private func markCopied(ids: [UUID]) {
        let copiedIDs = Set(ids)
        let copiedAt = Date()
        let updatedCards = sortedCards(
            cards.map { card in
                guard copiedIDs.contains(card.id) else {
                    return card
                }

                return card.markCopied(at: copiedAt)
            }
        )

        do {
            try cardStore.save(updatedCards)
            storageErrorMessage = nil
        } catch {
            logStorageFailure("Card copy state save failed", error: error)
            return
        }

        cards = updatedCards
        clearSelection()
    }

    private func sortedCards(_ cards: [CaptureCard]) -> [CaptureCard] {
        CaptureCardGrouping.stackCards(cards)
    }

    private func cleanupManagedAttachments(removedCards: [CaptureCard], remainingCards: [CaptureCard]) {
        let referencedURLs = Set(remainingCards.compactMap { $0.screenshotURL?.standardizedFileURL })
        let removableURLs = Set(removedCards.compactMap { $0.screenshotURL?.standardizedFileURL })

        for fileURL in removableURLs where !referencedURLs.contains(fileURL) {
            do {
                try attachmentStore.removeManagedFile(at: fileURL)
            } catch {
                logStorageFailure("Managed attachment cleanup failed", error: error)
            }
        }
    }

    private func pruneOrphanedManagedAttachments() {
        let referencedURLs = Set(cards.compactMap { $0.screenshotURL?.standardizedFileURL })

        do {
            try attachmentStore.pruneUnreferencedManagedFiles(referencedFileURLs: referencedURLs)
        } catch {
            logStorageFailure("Managed attachment prune failed", error: error)
        }
    }

    private func cleanupImportedAttachment(atPath path: String?) {
        guard let path else {
            return
        }

        do {
            try attachmentStore.removeManagedFile(at: URL(fileURLWithPath: path))
        } catch {
            logStorageFailure("Imported attachment rollback failed", error: error)
        }
    }

    private func migrateLegacyExternalAttachmentsIfNeeded() {
        var migratedCards = cards
        var didChange = false

        for index in migratedCards.indices {
            let card = migratedCards[index]
            guard let screenshotURL = card.screenshotURL?.standardizedFileURL else {
                continue
            }

            guard !attachmentStore.isManagedFile(screenshotURL) else {
                continue
            }

            let migratedPath: String?
            if FileManager.default.fileExists(atPath: screenshotURL.path) {
                do {
                    migratedPath = try ScreenshotDirectoryResolver.withAccessIfNeeded(to: screenshotURL) { scopedURL in
                        try attachmentStore.importScreenshot(from: scopedURL, ownerID: card.id).path
                    }
                } catch {
                    logStorageFailure("Legacy screenshot migration failed", error: error)
                    migratedPath = nil
                }
            } else {
                migratedPath = nil
            }

            if migratedPath != card.screenshotPath {
                migratedCards[index] = CaptureCard(
                    id: card.id,
                    bodyText: card.bodyText,
                    createdAt: card.createdAt,
                    suggestedTarget: card.suggestedTarget,
                    screenshotPath: migratedPath,
                    lastCopiedAt: card.lastCopiedAt,
                    sortOrder: card.sortOrder
                )
                didChange = true
            }
        }

        guard didChange else {
            return
        }

        let sortedMigratedCards = sortedCards(migratedCards)

        do {
            try cardStore.save(sortedMigratedCards)
            storageErrorMessage = nil
            cards = sortedMigratedCards
        } catch {
            logStorageFailure("Legacy screenshot save failed", error: error)
        }
    }

    private func logStorageFailure(_ message: String, error: Error) {
        storageErrorMessage = "\(message): \(error.localizedDescription)"
        NSLog("%@: %@", message, String(describing: error))
    }

    private func reservePendingScreenshotSlotIfNeeded() {
        guard pendingScreenshotAttachment == nil else {
            clearPendingScreenshotReservation()
            return
        }

        if let signal = screenshotMonitor.mostRecentScreenshotSignal(maxAge: AppUIConstants.recentScreenshotMaxAge),
           signal.identityKey != ignoredRecentScreenshotIdentity {
            beginPendingScreenshotReservation(identityKey: signal.identityKey)
            return
        }

        if screenshotMonitor.hasRecentDirectoryActivity(maxAge: AppUIConstants.recentScreenshotPlaceholderGrace) {
            beginPendingScreenshotReservation(identityKey: pendingScreenshotReservationIdentity)
            return
        }

        if let deadline = pendingScreenshotReservationDeadline, Date() < deadline {
            isAwaitingRecentScreenshot = true
            return
        }

        clearPendingScreenshotReservation()
    }

    private func clearPendingScreenshotReservation() {
        pendingScreenshotReservationIdentity = nil
        pendingScreenshotReservationDeadline = nil
        isAwaitingRecentScreenshot = false
    }

    private func beginPendingScreenshotReservation(identityKey: String?) {
        pendingScreenshotReservationIdentity = identityKey
        pendingScreenshotReservationDeadline = Date().addingTimeInterval(
            AppUIConstants.recentScreenshotPlaceholderGrace
        )
        isAwaitingRecentScreenshot = true
    }


    private func nextTopSortOrder() -> Double {
        let maximum = cards
            .map(\.sortOrder)
            .max() ?? 0

        return maximum + 1
    }

    private func refreshSuggestedTargetDebugState(relativeTo date: Date = Date()) {
        if let suggestedTarget = draftSuggestedTargetOverride
            ?? suggestedTargetProvider.currentFreshSuggestedTarget(
                relativeTo: date,
                freshness: AppUIConstants.suggestedTargetFreshness
            ) {
            captureDebugSuggestedTarget = suggestedTarget
            captureDebugSuggestedTargetLine = suggestedTarget.workspaceLabel
            return
        }

        captureDebugSuggestedTarget = nil
        captureDebugSuggestedTargetLine = "No recent terminal"
    }

    private func syncAvailableSuggestedTargets() {
        availableSuggestedTargets = suggestedTargetProvider.availableSuggestedTargets()
        syncCaptureSuggestedTargetSelection()
    }

    private var captureSuggestedTargetChoices: [CaptureSuggestedTargetChoice] {
        var choices: [CaptureSuggestedTargetChoice] = []

        if let automaticSuggestedTarget {
            choices.append(.automatic(automaticSuggestedTarget))
        }

        let filteredTargets: [CaptureSuggestedTarget]
        if let automaticSuggestedTarget {
            filteredTargets = availableSuggestedTargets.filter { $0 != automaticSuggestedTarget }
        } else {
            filteredTargets = availableSuggestedTargets
        }

        choices.append(contentsOf: filteredTargets.map(CaptureSuggestedTargetChoice.explicit))
        return choices
    }

    private func syncCaptureSuggestedTargetSelection() {
        let choices = captureSuggestedTargetChoices
        guard !choices.isEmpty else {
            selectedCaptureSuggestedTargetIndex = 0
            return
        }

        if draftSuggestedTargetOverride == nil,
           automaticSuggestedTarget != nil {
            selectedCaptureSuggestedTargetIndex = 0
            return
        }

        if let draftSuggestedTargetOverride,
           let matchingIndex = choices.firstIndex(where: { choice in
               !choice.isAutomatic && choice.target == draftSuggestedTargetOverride
           }) {
            selectedCaptureSuggestedTargetIndex = matchingIndex
            return
        }

        selectedCaptureSuggestedTargetIndex = min(selectedCaptureSuggestedTargetIndex, choices.count - 1)
    }
}

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
final class RecentTerminalTargetTracker: SuggestedTargetProviding {
    var onChange: (() -> Void)?

    private var activationObserver: NSObjectProtocol?
    private var latestTarget: CaptureSuggestedTarget?
    private var availableTargets: [CaptureSuggestedTarget] = []
    private let resolutionQueue = DispatchQueue(
        label: "com.promptcue.recent-terminal-target-resolution",
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
              let appName = supportedAppName(for: bundleIdentifier) else {
            return
        }

        let capturedAt = Date()
        let windowTitle = frontWindowTitle(forProcessIdentifier: application.processIdentifier)
        let provisionalTarget = CaptureSuggestedTarget(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            capturedAt: capturedAt,
            confidence: .low
        )

        latestTarget = provisionalTarget
        onChange?()
        refreshAvailableSuggestedTargets()

        let resolutionID = UUID()
        latestResolutionID = resolutionID

        resolutionQueue.async { [weak self] in
            let resolvedTarget = buildDetailedSuggestedTarget(
                appName: appName,
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

    private func supportedAppName(for bundleIdentifier: String) -> String? {
        switch bundleIdentifier {
        case "com.apple.Terminal":
            return "Terminal"
        case "com.googlecode.iterm2":
            return "iTerm2"
        default:
            return nil
        }
    }

    private func frontWindowTitle(forProcessIdentifier processIdentifier: pid_t) -> String? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == processIdentifier else {
                continue
            }

            if let layer = window[kCGWindowLayer as String] as? Int,
               layer != 0 {
                continue
            }

            guard let title = window[kCGWindowName as String] as? String else {
                continue
            }

            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }
}

private struct TerminalSessionContext {
    let tty: String
    let sessionIdentifier: String?
}

private struct TerminalWindowSnapshot {
    let appName: String
    let bundleIdentifier: String
    let windowTitle: String?
    let sessionIdentifier: String?
    let tty: String
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
    let snapshots = enumerateTerminalWindowSnapshots() + enumerateITermWindowSnapshots()
    var deduplicatedSnapshots: [String: TerminalWindowSnapshot] = [:]

    for snapshot in snapshots {
        deduplicatedSnapshots["\(snapshot.bundleIdentifier)|\(snapshot.tty)"] = snapshot
    }

    let targets = deduplicatedSnapshots.values.compactMap { snapshot in
        buildDetailedSuggestedTarget(
            appName: snapshot.appName,
            bundleIdentifier: snapshot.bundleIdentifier,
            fallbackWindowTitle: snapshot.windowTitle,
            capturedAt: capturedAt,
            sessionContext: TerminalSessionContext(
                tty: snapshot.tty,
                sessionIdentifier: snapshot.sessionIdentifier ?? snapshot.tty
            )
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

        let appComparison = lhs.appName.localizedCaseInsensitiveCompare(rhs.appName)
        if appComparison != .orderedSame {
            return appComparison == .orderedAscending
        }

        return lhs.workspaceLabel.localizedCaseInsensitiveCompare(rhs.workspaceLabel) == .orderedAscending
    }
}

private func enumerateTerminalWindowSnapshots() -> [TerminalWindowSnapshot] {
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

private func enumerateITermWindowSnapshots() -> [TerminalWindowSnapshot] {
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
) -> [TerminalWindowSnapshot] {
    output
        .components(separatedBy: .newlines)
        .compactMap { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else {
                return nil
            }

            let parts = trimmedLine.split(
                separator: "|",
                maxSplits: 2,
                omittingEmptySubsequences: false
            )
            guard parts.count == 3 else {
                return nil
            }

            let windowID = String(parts[0])
            let windowTitle = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tty = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tty.isEmpty else {
                return nil
            }

            return TerminalWindowSnapshot(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                windowTitle: windowTitle.isEmpty ? nil : windowTitle,
                sessionIdentifier: windowID,
                tty: tty
            )
        }
}

private func suggestedTargetMatchKey(_ target: CaptureSuggestedTarget) -> String {
    [
        target.bundleIdentifier,
        target.sessionIdentifier ?? "",
        target.repositoryRoot ?? "",
        target.currentWorkingDirectory ?? "",
        target.windowTitle ?? "",
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

    guard let pid = processLines.last?.split(whereSeparator: \.isWhitespace).first else {
        return nil
    }

    guard let lsofOutput = runCommand(
        executableURL: URL(fileURLWithPath: "/usr/sbin/lsof"),
        arguments: ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]
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
