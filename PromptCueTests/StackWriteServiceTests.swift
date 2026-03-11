import Foundation
import XCTest
@testable import Prompt_Cue
import PromptCueCore

@MainActor
final class StackWriteServiceTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var databaseURL: URL!
    private var attachmentsURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        attachmentsURL = tempDirectoryURL.appendingPathComponent("Attachments", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }

        tempDirectoryURL = nil
        databaseURL = nil
        attachmentsURL = nil
        try super.tearDownWithError()
    }

    func testCreateNoteTrimsTextAndUsesNextActiveSortOrder() throws {
        let active = CaptureCard(
            id: UUID(),
            text: "Active",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            sortOrder: 10
        )
        let copied = CaptureCard(
            id: UUID(),
            text: "Copied",
            createdAt: Date(timeIntervalSinceReferenceDate: 200),
            lastCopiedAt: Date(timeIntervalSinceReferenceDate: 250),
            sortOrder: 99
        )
        try saveCards([active, copied])

        let service = makeService()
        let note = try service.createNote(
            StackNoteCreateRequest(
                text: "  New note  ",
                createdAt: Date(timeIntervalSinceReferenceDate: 300)
            )
        )

        XCTAssertEqual(note.text, "New note")
        XCTAssertEqual(note.sortOrder, 11)
        XCTAssertNil(note.lastCopiedAt)

        let loadedCards = try CardStore(databaseURL: databaseURL).load()
        XCTAssertTrue(loadedCards.contains(note))
    }

    func testCreateNoteAllowsScreenshotOnlyFallbackText() throws {
        let service = makeService()

        let note = try service.createNote(
            StackNoteCreateRequest(
                text: "   ",
                screenshotPath: "/tmp/capture.png"
            )
        )

        XCTAssertEqual(note.text, "Screenshot attached")
        XCTAssertEqual(note.screenshotPath, "/tmp/capture.png")
    }

    func testUpdateNotePreservesCopiedStateAndClearsOptionalMetadata() throws {
        let suggestedTarget = CaptureSuggestedTarget(
            appName: "Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            windowTitle: "PromptCue.swift",
            sessionIdentifier: "tab-7",
            currentWorkingDirectory: "/Users/ilwon/dev/PromptCue/App",
            repositoryRoot: "/Users/ilwon/dev/PromptCue",
            repositoryName: "PromptCue",
            branch: "feature/mcp",
            capturedAt: Date(timeIntervalSinceReferenceDate: 100),
            confidence: .high
        )
        let note = CaptureCard(
            id: UUID(),
            text: "Original",
            suggestedTarget: suggestedTarget,
            createdAt: Date(timeIntervalSinceReferenceDate: 200),
            screenshotPath: "/tmp/original.png",
            lastCopiedAt: Date(timeIntervalSinceReferenceDate: 300),
            sortOrder: 77
        )
        try saveCards([note])

        let service = makeService()
        let updated = try XCTUnwrap(
            service.updateNote(
                id: note.id,
                changes: StackNoteUpdate(
                    text: "  Updated  ",
                    suggestedTarget: .clear,
                    screenshotPath: .clear
                )
            )
        )

        XCTAssertEqual(updated.text, "Updated")
        XCTAssertNil(updated.suggestedTarget)
        XCTAssertNil(updated.screenshotPath)
        XCTAssertEqual(updated.lastCopiedAt, note.lastCopiedAt)
        XCTAssertEqual(updated.sortOrder, note.sortOrder)
    }

    func testDeleteNoteRemovesManagedAttachmentWhenUnreferenced() throws {
        let attachmentStore = AttachmentStore(baseDirectoryURL: attachmentsURL)
        let sourceURL = tempDirectoryURL.appendingPathComponent("shot.png")
        try Data("png".utf8).write(to: sourceURL)

        let noteID = UUID()
        let managedURL = try attachmentStore.importScreenshot(from: sourceURL, ownerID: noteID)
        let note = CaptureCard(
            id: noteID,
            text: "With attachment",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            screenshotPath: managedURL.path,
            sortOrder: 10
        )
        try saveCards([note])

        let service = makeService(attachmentStore: attachmentStore)
        let deleted = try service.deleteNote(id: noteID)

        XCTAssertTrue(deleted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertTrue(try CardStore(databaseURL: databaseURL).load().isEmpty)
    }

    func testDeleteNoteKeepsManagedAttachmentWhenStillReferenced() throws {
        let attachmentStore = AttachmentStore(baseDirectoryURL: attachmentsURL)
        let sourceURL = tempDirectoryURL.appendingPathComponent("shared.png")
        try Data("png".utf8).write(to: sourceURL)

        let firstID = UUID()
        let managedURL = try attachmentStore.importScreenshot(from: sourceURL, ownerID: firstID)
        let first = CaptureCard(
            id: firstID,
            text: "First",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            screenshotPath: managedURL.path,
            sortOrder: 10
        )
        let second = CaptureCard(
            id: UUID(),
            text: "Second",
            createdAt: Date(timeIntervalSinceReferenceDate: 200),
            screenshotPath: managedURL.path,
            sortOrder: 20
        )
        try saveCards([first, second])

        let service = makeService(attachmentStore: attachmentStore)
        let deleted = try service.deleteNote(id: first.id)

        XCTAssertTrue(deleted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertEqual(try CardStore(databaseURL: databaseURL).load(), [second])
    }

    func testMissingNotesReturnNilOrFalse() throws {
        let service = makeService()

        XCTAssertNil(
            try service.updateNote(
                id: UUID(),
                changes: StackNoteUpdate(text: "Updated")
            )
        )
        XCTAssertFalse(try service.deleteNote(id: UUID()))
    }

    func testEmptyTextWithoutScreenshotThrows() throws {
        let service = makeService()

        XCTAssertThrowsError(
            try service.createNote(StackNoteCreateRequest(text: " \n "))
        ) { error in
            XCTAssertEqual(error as? StackWriteServiceError, .emptyNote)
        }
    }

    private func makeService(
        attachmentStore: (any AttachmentStoring)? = nil
    ) -> StackWriteService {
        let database = PromptCueDatabase(databaseURL: databaseURL)
        return StackWriteService(
            cardStore: CardStore(database: database),
            attachmentStore: attachmentStore
                ?? AttachmentStore(baseDirectoryURL: attachmentsURL)
        )
    }

    private func saveCards(_ cards: [CaptureCard]) throws {
        try CardStore(databaseURL: databaseURL).save(cards)
    }
}
