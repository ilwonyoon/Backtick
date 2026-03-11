import Foundation
import PromptCueCore

enum StackWriteServiceError: Error, Equatable {
    case emptyNote
}

enum StackOptionalUpdate<Value: Equatable & Sendable>: Equatable, Sendable {
    case keep
    case set(Value)
    case clear
}

struct StackNoteCreateRequest: Equatable, Sendable {
    let id: UUID
    let text: String
    let suggestedTarget: CaptureSuggestedTarget?
    let screenshotPath: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        suggestedTarget: CaptureSuggestedTarget? = nil,
        screenshotPath: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.suggestedTarget = suggestedTarget
        self.screenshotPath = screenshotPath
        self.createdAt = createdAt
    }
}

struct StackNoteUpdate: Equatable, Sendable {
    let text: String?
    let suggestedTarget: StackOptionalUpdate<CaptureSuggestedTarget>
    let screenshotPath: StackOptionalUpdate<String>

    init(
        text: String? = nil,
        suggestedTarget: StackOptionalUpdate<CaptureSuggestedTarget> = .keep,
        screenshotPath: StackOptionalUpdate<String> = .keep
    ) {
        self.text = text
        self.suggestedTarget = suggestedTarget
        self.screenshotPath = screenshotPath
    }
}

@MainActor
final class StackWriteService {
    private let cardStore: CardStore
    private let attachmentStore: any AttachmentStoring

    init(
        cardStore: CardStore,
        attachmentStore: any AttachmentStoring
    ) {
        self.cardStore = cardStore
        self.attachmentStore = attachmentStore
    }

    convenience init(
        fileManager: FileManager = .default,
        databaseURL: URL? = nil,
        attachmentBaseDirectoryURL: URL? = nil
    ) {
        let database = PromptCueDatabase(fileManager: fileManager, databaseURL: databaseURL)
        self.init(
            cardStore: CardStore(database: database),
            attachmentStore: AttachmentStore(
                fileManager: fileManager,
                baseDirectoryURL: attachmentBaseDirectoryURL
            )
        )
    }

    func createNote(_ request: StackNoteCreateRequest) throws -> CaptureCard {
        let existingCards = try cardStore.load()
        let note = CaptureCard(
            id: request.id,
            text: try normalizedText(
                rawText: request.text,
                screenshotPath: request.screenshotPath
            ),
            suggestedTarget: request.suggestedTarget,
            createdAt: request.createdAt,
            screenshotPath: request.screenshotPath,
            sortOrder: nextTopSortOrder(in: existingCards)
        )

        try cardStore.upsert(note)
        return note
    }

    func updateNote(id: UUID, changes: StackNoteUpdate) throws -> CaptureCard? {
        let existingCards = try cardStore.load()
        guard let existingNote = existingCards.first(where: { $0.id == id }) else {
            return nil
        }

        let screenshotPath = resolvedValue(
            current: existingNote.screenshotPath,
            update: changes.screenshotPath
        )
        let updatedNote = CaptureCard(
            id: existingNote.id,
            text: try normalizedText(
                rawText: changes.text ?? existingNote.text,
                screenshotPath: screenshotPath
            ),
            suggestedTarget: resolvedValue(
                current: existingNote.suggestedTarget,
                update: changes.suggestedTarget
            ),
            createdAt: existingNote.createdAt,
            screenshotPath: screenshotPath,
            lastCopiedAt: existingNote.lastCopiedAt,
            sortOrder: existingNote.sortOrder
        )

        try cardStore.upsert(updatedNote)
        return updatedNote
    }

    @discardableResult
    func deleteNote(id: UUID) throws -> Bool {
        let existingCards = try cardStore.load()
        guard let removedNote = existingCards.first(where: { $0.id == id }) else {
            return false
        }

        let remainingCards = existingCards.filter { $0.id != id }
        try cardStore.delete(id: id)
        cleanupManagedAttachments(
            removedCards: [removedNote],
            remainingCards: remainingCards
        )
        return true
    }

    private func nextTopSortOrder(in cards: [CaptureCard]) -> Double {
        let maximum = cards
            .filter { !$0.isCopied }
            .map(\.sortOrder)
            .max() ?? 0

        return maximum + 1
    }

    private func normalizedText(
        rawText: String,
        screenshotPath: String?
    ) throws -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            guard screenshotPath != nil else {
                throw StackWriteServiceError.emptyNote
            }
            return "Screenshot attached"
        }

        return trimmed
    }

    private func cleanupManagedAttachments(
        removedCards: [CaptureCard],
        remainingCards: [CaptureCard]
    ) {
        let referencedURLs = Set(remainingCards.compactMap { $0.screenshotURL?.standardizedFileURL })
        let removableURLs = Set(removedCards.compactMap { $0.screenshotURL?.standardizedFileURL })

        for fileURL in removableURLs where !referencedURLs.contains(fileURL) {
            do {
                try attachmentStore.removeManagedFile(at: fileURL)
            } catch {
                NSLog(
                    "StackWriteService attachment cleanup failed: %@",
                    error.localizedDescription
                )
            }
        }
    }
}

private func resolvedValue<Value>(
    current: Value,
    update: StackOptionalUpdate<Value>
) -> Value {
    switch update {
    case .keep:
        return current
    case .set(let value):
        return value
    case .clear:
        return current
    }
}

private func resolvedValue<Value>(
    current: Value?,
    update: StackOptionalUpdate<Value>
) -> Value? {
    switch update {
    case .keep:
        return current
    case .set(let value):
        return value
    case .clear:
        return nil
    }
}
