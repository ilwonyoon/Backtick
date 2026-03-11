import Foundation
import XCTest
@testable import Prompt_Cue
import PromptCueCore

@MainActor
final class StackExecutionServiceTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }

        tempDirectoryURL = nil
        databaseURL = nil
        try super.tearDownWithError()
    }

    func testMarkExecutedUpdatesCopiedStateAndCreatesCopyEvent() throws {
        let note = CaptureCard(
            id: UUID(),
            text: "Ship MCP action",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            sortOrder: 10
        )
        try saveCards([note])

        let service = makeService()
        let baseTimestamp = Date(timeIntervalSinceReferenceDate: 200)
        let result = try service.markExecuted(
            noteIDs: [note.id],
            sessionID: " run-42 ",
            copiedAt: baseTimestamp
        )

        let expectedTimestamp = baseTimestamp.addingTimeInterval(0.001)
        let updatedNote = try XCTUnwrap(result.notes.first)
        let copyEvent = try XCTUnwrap(result.copyEvents.first)

        XCTAssertEqual(updatedNote.id, note.id)
        XCTAssertEqual(updatedNote.lastCopiedAt, expectedTimestamp)
        XCTAssertEqual(copyEvent.noteID, note.id)
        XCTAssertEqual(copyEvent.sessionID, "run-42")
        XCTAssertEqual(copyEvent.copiedAt, expectedTimestamp)
        XCTAssertEqual(copyEvent.copiedVia, .agentRun)
        XCTAssertEqual(copyEvent.copiedBy, .mcp)

        let storedNote = try XCTUnwrap(CardStore(databaseURL: databaseURL).load().first)
        let storedEvents = try CopyEventStore(databaseURL: databaseURL).loadCopyEvents(for: note.id)

        XCTAssertEqual(storedNote.lastCopiedAt, expectedTimestamp)
        XCTAssertEqual(storedEvents, [copyEvent])
    }

    func testMarkExecutedPreservesRequestedOrderAcrossMultipleNotes() throws {
        let first = CaptureCard(
            id: UUID(),
            text: "First",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            sortOrder: 10
        )
        let second = CaptureCard(
            id: UUID(),
            text: "Second",
            createdAt: Date(timeIntervalSinceReferenceDate: 110),
            sortOrder: 20
        )
        try saveCards([first, second])

        let service = makeService()
        let result = try service.markExecuted(
            noteIDs: [second.id, first.id],
            copiedAt: Date(timeIntervalSinceReferenceDate: 300)
        )

        XCTAssertEqual(result.notes.map(\.id), [second.id, first.id])
        XCTAssertEqual(result.copyEvents.map(\.noteID), [second.id, first.id])

        let copiedNotes = try StackReadService(databaseURL: databaseURL).listNotes(scope: .copied)
        XCTAssertEqual(copiedNotes.map(\.id), [second.id, first.id])
    }

    func testMarkExecutedSkipsMissingNotes() throws {
        let note = CaptureCard(
            id: UUID(),
            text: "Existing",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            sortOrder: 10
        )
        try saveCards([note])

        let service = makeService()
        let result = try service.markExecuted(
            noteIDs: [UUID(), note.id, note.id]
        )

        XCTAssertEqual(result.notes.map(\.id), [note.id])
        XCTAssertEqual(result.copyEvents.map(\.noteID), [note.id])
        XCTAssertEqual(
            try CopyEventStore(databaseURL: databaseURL).loadCopyEvents().map(\.noteID),
            [note.id]
        )
    }

    func testMarkExecutedAppendsHistoryForPreviouslyCopiedNote() throws {
        let note = CaptureCard(
            id: UUID(),
            text: "Existing copied note",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            lastCopiedAt: Date(timeIntervalSinceReferenceDate: 150),
            sortOrder: 10
        )
        let previousEvent = CopyEvent(
            id: UUID(),
            noteID: note.id,
            sessionID: "run-1",
            copiedAt: Date(timeIntervalSinceReferenceDate: 150),
            copiedVia: .clipboard,
            copiedBy: .user
        )
        try saveCards([note])
        try CopyEventStore(databaseURL: databaseURL).recordCopyEvents([previousEvent])

        let service = makeService()
        let result = try service.markExecuted(
            noteIDs: [note.id],
            sessionID: "run-2",
            copiedAt: Date(timeIntervalSinceReferenceDate: 250)
        )

        let newEvent = try XCTUnwrap(result.copyEvents.first)
        let detail = try XCTUnwrap(StackReadService(databaseURL: databaseURL).noteDetail(id: note.id))

        XCTAssertEqual(detail.note.lastCopiedAt, newEvent.copiedAt)
        XCTAssertEqual(detail.copyEvents, [newEvent, previousEvent])
    }

    func testMarkExecutedReturnsEmptyResultForEmptyInput() throws {
        let service = makeService()
        let result = try service.markExecuted(noteIDs: [])

        XCTAssertTrue(result.notes.isEmpty)
        XCTAssertTrue(result.copyEvents.isEmpty)
        XCTAssertTrue(try CardStore(databaseURL: databaseURL).load().isEmpty)
        XCTAssertTrue(try CopyEventStore(databaseURL: databaseURL).loadCopyEvents().isEmpty)
    }

    private func makeService() -> StackExecutionService {
        StackExecutionService(database: PromptCueDatabase(databaseURL: databaseURL))
    }

    private func saveCards(_ cards: [CaptureCard]) throws {
        try CardStore(databaseURL: databaseURL).save(cards)
    }
}
