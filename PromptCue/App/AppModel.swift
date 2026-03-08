import AppKit
import Combine
import Foundation
import PromptCueCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var cards: [CaptureCard] = []
    @Published private(set) var storageErrorMessage: String?
    @Published var draftText = ""
    @Published var draftEditorContentHeight: CGFloat = 0
    @Published var pendingScreenshotAttachment: ScreenshotAttachment?
    @Published var selectedCardIDs: Set<UUID> = []

    private let cardStore: CardStore
    private let screenshotMonitor: ScreenshotMonitor
    private let attachmentStore: AttachmentStoring
    private var cleanupTimer: Timer?
    private var captureSessionTimer: Timer?
    private var ignoredRecentScreenshotPath: String?

    init(
        cardStore: CardStore,
        screenshotMonitor: ScreenshotMonitor,
        attachmentStore: AttachmentStoring
    ) {
        self.cardStore = cardStore
        self.screenshotMonitor = screenshotMonitor
        self.attachmentStore = attachmentStore
    }

    convenience init() {
        self.init(
            cardStore: CardStore(),
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore()
        )
    }

    var selectionCount: Int {
        selectedCardIDs.count
    }

    var selectedCardsInDisplayOrder: [CaptureCard] {
        cards.filter { selectedCardIDs.contains($0.id) }
    }

    func start() {
        reloadCards()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.purgeExpiredCards()
            }
        }
    }

    func stop() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        captureSessionTimer?.invalidate()
        captureSessionTimer = nil
    }

    func reloadCards() {
        do {
            cards = sortedCards(try cardStore.load())
            storageErrorMessage = nil
        } catch {
            logStorageFailure("Card load failed", error: error)
            return
        }

        purgeExpiredCards()
        pruneOrphanedManagedAttachments()
    }

    func beginCaptureSession() {
        refreshPendingScreenshot()

        guard captureSessionTimer == nil else {
            return
        }

        captureSessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPendingScreenshot()
            }
        }
    }

    func endCaptureSession() {
        captureSessionTimer?.invalidate()
        captureSessionTimer = nil
    }

    func refreshPendingScreenshot() {
        let candidate = screenshotMonitor.mostRecentScreenshot(maxAge: AppUIConstants.recentScreenshotMaxAge)

        guard let candidate else {
            return
        }

        guard candidate.path != pendingScreenshotAttachment?.path else {
            return
        }

        guard candidate.path != ignoredRecentScreenshotPath else {
            return
        }

        pendingScreenshotAttachment = candidate
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
            do {
                importedScreenshotPath = try attachmentStore.importScreenshot(
                    from: URL(fileURLWithPath: attachment.path),
                    ownerID: newCardID
                ).path
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
            createdAt: Date(),
            screenshotPath: importedScreenshotPath
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
        if let attachment {
            ignoredRecentScreenshotPath = attachment.path
        }
        pendingScreenshotAttachment = nil
        return true
    }

    func clearDraft() {
        draftText = ""
        draftEditorContentHeight = 0
        pendingScreenshotAttachment = nil
    }

    func dismissPendingScreenshot() {
        guard let pendingScreenshotAttachment else {
            return
        }

        ignoredRecentScreenshotPath = pendingScreenshotAttachment.path
        self.pendingScreenshotAttachment = nil
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
        CardStackOrdering.sort(cards)
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

    private func logStorageFailure(_ message: String, error: Error) {
        storageErrorMessage = "\(message): \(error.localizedDescription)"
        NSLog("%@: %@", message, String(describing: error))
    }
}
