import Foundation
import GRDB
import UniformTypeIdentifiers
import XCTest
@testable import Prompt_Cue
import PromptCueCore

@MainActor
final class StorageServicesTests: XCTestCase {
    private final class NotesExportSpy: NotesExporting {
        private(set) var exportedCards: [CaptureCard] = []
        private(set) var exportedDate: Date?
        var stubbedResult = NotesExportResult(
            noteTitle: "Prompt Cue · 2099-01-01",
            noteIdentifier: "notes-export-spy"
        )

        func exportDailyDigest(cards: [CaptureCard], date: Date) throws -> NotesExportResult {
            exportedCards = cards
            exportedDate = date
            return stubbedResult
        }
    }

    @MainActor
    private final class SuggestedTargetProviderSpy: SuggestedTargetProviding {
        var onChange: (() -> Void)?
        var currentTarget: CaptureSuggestedTarget?
        var availableTargets: [CaptureSuggestedTarget] = []
        private(set) var startCallCount = 0
        private(set) var stopCallCount = 0
        private(set) var refreshAvailableCallCount = 0

        func start() {
            startCallCount += 1
        }

        func stop() {
            stopCallCount += 1
        }

        func currentFreshSuggestedTarget(
            relativeTo date: Date,
            freshness: TimeInterval
        ) -> CaptureSuggestedTarget? {
            guard let currentTarget,
                  currentTarget.isFresh(relativeTo: date, freshness: freshness) else {
                return nil
            }

            return currentTarget
        }

        func availableSuggestedTargets() -> [CaptureSuggestedTarget] {
            availableTargets
        }

        func refreshAvailableSuggestedTargets() {
            refreshAvailableCallCount += 1
        }
    }

    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testAttachmentStoreImportsAndPrunesManagedFiles() throws {
        let attachmentsURL = tempDirectoryURL.appendingPathComponent("Attachments", isDirectory: true)
        let store = AttachmentStore(baseDirectoryURL: attachmentsURL)

        let sourceURL = tempDirectoryURL.appendingPathComponent("shot.png")
        try Data("png".utf8).write(to: sourceURL)

        let keptURL = try store.importScreenshot(from: sourceURL, ownerID: UUID())
        let orphanURL = try store.importScreenshot(from: sourceURL, ownerID: UUID())

        XCTAssertTrue(FileManager.default.fileExists(atPath: keptURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanURL.path))
        XCTAssertTrue(store.isManagedFile(keptURL))

        try store.pruneUnreferencedManagedFiles(referencedFileURLs: [keptURL])

        XCTAssertTrue(FileManager.default.fileExists(atPath: keptURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanURL.path))
    }

    func testCardStoreRoundTripsStructuredMetadata() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let store = CardStore(databaseURL: databaseURL)
        let copiedAt = Date().addingTimeInterval(-30)
        let expectedCard = CaptureCard(
            id: UUID(),
            bodyText: "Round trip",
            createdAt: Date(),
            suggestedTarget: CaptureSuggestedTarget(
                appName: "iTerm2",
                bundleIdentifier: "com.googlecode.iterm2",
                windowTitle: "auth-service",
                currentWorkingDirectory: "/Users/ilwonyoon/projects/auth-service",
                repositoryRoot: "/Users/ilwonyoon/projects/auth-service",
                repositoryName: "auth-service",
                branch: "feature/login",
                capturedAt: Date().addingTimeInterval(-12)
            ),
            screenshotPath: "/tmp/screenshot.png",
            lastCopiedAt: copiedAt,
            sortOrder: 42
        )

        try store.save([expectedCard])
        let loadedCards = try store.load()

        XCTAssertEqual(loadedCards.count, 1)
        XCTAssertEqual(loadedCards.first?.id, expectedCard.id)
        XCTAssertEqual(loadedCards.first?.bodyText, expectedCard.bodyText)
        XCTAssertEqual(loadedCards.first?.text, expectedCard.text)
        XCTAssertEqual(loadedCards.first?.suggestedTarget, expectedCard.suggestedTarget)
        XCTAssertEqual(loadedCards.first?.screenshotPath, expectedCard.screenshotPath)
        XCTAssertEqual(loadedCards.first?.sortOrder, expectedCard.sortOrder)
        let loadedCopiedAt = try XCTUnwrap(loadedCards.first?.lastCopiedAt)
        XCTAssertLessThan(abs(loadedCopiedAt.timeIntervalSince(copiedAt)), 1)
    }

    func testCardStoreMigratesLegacyTextOnlyRows() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("LegacyPromptCue.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.write { db in
            try db.create(table: "cards") { table in
                table.column("id", .text).notNull().primaryKey()
                table.column("text", .text).notNull()
                table.column("createdAt", .datetime).notNull()
                table.column("screenshotPath", .text)
                table.column("sortOrder", .double).notNull()
                table.column("lastCopiedAt", .datetime)
            }

            try db.execute(
                sql: """
                INSERT INTO cards (id, text, createdAt, screenshotPath, sortOrder, lastCopiedAt)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    UUID().uuidString,
                    "legacy body",
                    Date(timeIntervalSince1970: 1_234),
                    "/tmp/legacy.png",
                    7,
                    nil as Date?,
                ]
            )
        }

        let store = CardStore(databaseURL: databaseURL)
        let cards = try store.load()

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.bodyText, "legacy body")
        XCTAssertEqual(cards.first?.screenshotPath, "/tmp/legacy.png")
    }

    func testAppModelEnablesNotesExportOnlyWhenTodayHasCards() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let notesExportSpy = NotesExportSpy()
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: notesExportSpy,
            suggestedTargetProvider: suggestedTargetProvider
        )

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date().addingTimeInterval(-86_400)
        try cardStore.save([
            CaptureCard(
                bodyText: "yesterday only",
                createdAt: yesterday,
                sortOrder: yesterday.timeIntervalSinceReferenceDate
            ),
        ])

        model.reloadCards()

        XCTAssertFalse(model.canExportTodayToNotes)
        XCTAssertNil(model.exportTodayToNotes())
        XCTAssertTrue(notesExportSpy.exportedCards.isEmpty)
    }

    func testAppModelExportsOnlyTodayCardsToNotes() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let notesExportSpy = NotesExportSpy()
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: notesExportSpy,
            suggestedTargetProvider: suggestedTargetProvider
        )

        let now = Date()
        let earlierToday = now.addingTimeInterval(-600)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86_400)
        try cardStore.save([
            CaptureCard(
                bodyText: "older export",
                createdAt: earlierToday,
                sortOrder: earlierToday.timeIntervalSinceReferenceDate
            ),
            CaptureCard(
                bodyText: "today export target",
                createdAt: now,
                sortOrder: now.timeIntervalSinceReferenceDate
            ),
            CaptureCard(
                bodyText: "yesterday ignore",
                createdAt: yesterday,
                sortOrder: yesterday.timeIntervalSinceReferenceDate
            ),
        ])

        model.reloadCards()

        XCTAssertTrue(model.canExportTodayToNotes)

        let result = model.exportTodayToNotes()

        XCTAssertEqual(result, notesExportSpy.stubbedResult)
        XCTAssertEqual(notesExportSpy.exportedCards.map(\.bodyText), ["today export target", "older export"])
        XCTAssertNotNil(notesExportSpy.exportedDate)
    }

    func testClipboardFormatterBuildsPlainTextExternalDragProvider() {
        let cards = [
            CaptureCard(bodyText: "first drag cue", createdAt: Date()),
            CaptureCard(bodyText: "second drag cue", createdAt: Date().addingTimeInterval(-30)),
        ]

        let provider = ClipboardFormatter.externalDragItemProvider(cards: cards)

        XCTAssertTrue(provider.registeredTypeIdentifiers.contains(UTType.text.identifier))
        XCTAssertTrue(provider.registeredTypeIdentifiers.contains(UTType.plainText.identifier))

        let expectation = expectation(description: "load drag payload")
        provider.loadObject(ofClass: NSString.self) { object, error in
            XCTAssertNil(error)
            XCTAssertEqual(object as? String, "• first drag cue\n• second drag cue")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testAppModelAttachesFreshSuggestedTargetOnCaptureSubmit() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        suggestedTargetProvider.currentTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "api-server",
            capturedAt: Date().addingTimeInterval(-10)
        )
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: NotesExportSpy(),
            suggestedTargetProvider: suggestedTargetProvider
        )

        model.draftText = "ship it"

        XCTAssertTrue(model.submitCapture())
        XCTAssertEqual(model.cards.count, 1)
        XCTAssertEqual(model.cards.first?.suggestedTarget, suggestedTargetProvider.currentTarget)
        XCTAssertEqual(model.captureDebugSuggestedTargetLine, "api-server")
    }

    func testAppModelLeavesSuggestedTargetEmptyWhenProviderHasNoFreshTarget() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        suggestedTargetProvider.currentTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "stale-shell",
            capturedAt: Date().addingTimeInterval(-(AppUIConstants.suggestedTargetFreshness + 5))
        )
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: NotesExportSpy(),
            suggestedTargetProvider: suggestedTargetProvider
        )

        model.draftText = "plain card"

        XCTAssertTrue(model.submitCapture())
        XCTAssertNil(model.cards.first?.suggestedTarget)
        XCTAssertEqual(model.captureDebugSuggestedTargetLine, "No recent terminal")
    }

    func testAppModelAllowsDraftSuggestedTargetOverride() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        suggestedTargetProvider.currentTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "api-server",
            currentWorkingDirectory: "/Users/ilwonyoon/projects/auth-service",
            repositoryRoot: "/Users/ilwonyoon/projects/auth-service",
            repositoryName: "auth-service",
            branch: "feature/login",
            capturedAt: Date().addingTimeInterval(-5)
        )
        suggestedTargetProvider.availableTargets = [
            CaptureSuggestedTarget(
                appName: "Terminal",
                bundleIdentifier: "com.apple.Terminal",
                windowTitle: "frontend-shell",
                currentWorkingDirectory: "/Users/ilwonyoon/projects/frontend-app",
                repositoryRoot: "/Users/ilwonyoon/projects/frontend-app",
                repositoryName: "frontend-app",
                branch: "fix/padding",
                capturedAt: Date().addingTimeInterval(-3)
            ),
        ]
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: NotesExportSpy(),
            suggestedTargetProvider: suggestedTargetProvider
        )

        model.beginCaptureSession()
        let overrideTarget = try XCTUnwrap(suggestedTargetProvider.availableTargets.first)
        model.chooseDraftSuggestedTarget(overrideTarget)
        model.draftText = "send this"

        XCTAssertTrue(model.submitCapture())
        XCTAssertEqual(model.cards.first?.suggestedTarget, overrideTarget)
    }

    func testAppModelAssignSuggestedTargetPersistsCardUpdate() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: NotesExportSpy(),
            suggestedTargetProvider: SuggestedTargetProviderSpy()
        )
        let card = CaptureCard(
            bodyText: "re-target me",
            createdAt: Date(),
            sortOrder: 1
        )
        try cardStore.save([card])
        model.reloadCards()

        let target = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            currentWorkingDirectory: "/Users/ilwonyoon/projects/auth-service/.worktrees/login",
            repositoryRoot: "/Users/ilwonyoon/projects/auth-service",
            repositoryName: "auth-service",
            branch: "feature/login",
            capturedAt: Date()
        )

        model.assignSuggestedTarget(target, to: card)

        XCTAssertEqual(model.cards.first?.suggestedTarget, target)
        let reloaded = try cardStore.load()
        XCTAssertEqual(reloaded.first?.suggestedTarget, target)
    }

    func testAppModelKeyboardSelectsCaptureSuggestedTargetChoice() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        suggestedTargetProvider.currentTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "api-server",
            repositoryName: "auth-service",
            branch: "feature/login",
            capturedAt: Date().addingTimeInterval(-5)
        )
        let explicitTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "frontend-shell",
            repositoryName: "frontend-app",
            branch: "fix/padding",
            capturedAt: Date().addingTimeInterval(-3)
        )
        suggestedTargetProvider.availableTargets = [explicitTarget]
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: NotesExportSpy(),
            suggestedTargetProvider: suggestedTargetProvider
        )

        model.beginCaptureSession()
        model.toggleCaptureSuggestedTargetChooser()

        XCTAssertTrue(model.isAutomaticCaptureSuggestedTargetHighlighted)
        XCTAssertEqual(model.highlightedCaptureSuggestedTarget, suggestedTargetProvider.currentTarget)

        XCTAssertTrue(model.moveCaptureSuggestedTargetSelection(by: 1))
        XCTAssertEqual(model.highlightedCaptureSuggestedTarget, explicitTarget)
        XCTAssertFalse(model.isAutomaticCaptureSuggestedTargetHighlighted)

        XCTAssertTrue(model.completeCaptureSuggestedTargetSelection())
        XCTAssertEqual(model.captureChooserTarget, explicitTarget)
        XCTAssertFalse(model.isShowingCaptureSuggestedTargetChooser)
    }

    func testAppModelCancelCaptureSuggestedTargetChooserKeepsAutomaticSelection() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        let automaticTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "api-server",
            repositoryName: "auth-service",
            branch: "feature/login",
            capturedAt: Date().addingTimeInterval(-5)
        )
        suggestedTargetProvider.currentTarget = automaticTarget
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: NotesExportSpy(),
            suggestedTargetProvider: suggestedTargetProvider
        )

        model.beginCaptureSession()
        model.toggleCaptureSuggestedTargetChooser()

        XCTAssertTrue(model.cancelCaptureSuggestedTargetSelection())
        XCTAssertFalse(model.isShowingCaptureSuggestedTargetChooser)
        XCTAssertEqual(model.captureChooserTarget, automaticTarget)
    }

    func testAppModelHoverHighlightUpdatesCaptureSuggestedTargetSelection() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        let automaticTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "api-server",
            repositoryName: "auth-service",
            branch: "feature/login",
            capturedAt: Date().addingTimeInterval(-5)
        )
        let explicitTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "frontend-shell",
            repositoryName: "frontend-app",
            branch: "fix/padding",
            capturedAt: Date().addingTimeInterval(-3)
        )
        suggestedTargetProvider.currentTarget = automaticTarget
        suggestedTargetProvider.availableTargets = [explicitTarget]
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: NotesExportSpy(),
            suggestedTargetProvider: suggestedTargetProvider
        )

        model.beginCaptureSession()
        model.toggleCaptureSuggestedTargetChooser()

        XCTAssertTrue(model.highlightCaptureSuggestedTarget(explicitTarget))
        XCTAssertEqual(model.highlightedCaptureSuggestedTarget, explicitTarget)
        XCTAssertFalse(model.isAutomaticCaptureSuggestedTargetHighlighted)
    }

    func testAppModelHoverHighlightCanReturnToAutomaticSuggestedTarget() throws {
        let databaseURL = tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let suggestedTargetProvider = SuggestedTargetProviderSpy()
        let automaticTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "api-server",
            repositoryName: "auth-service",
            branch: "feature/login",
            capturedAt: Date().addingTimeInterval(-5)
        )
        let explicitTarget = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "frontend-shell",
            repositoryName: "frontend-app",
            branch: "fix/padding",
            capturedAt: Date().addingTimeInterval(-3)
        )
        suggestedTargetProvider.currentTarget = automaticTarget
        suggestedTargetProvider.availableTargets = [explicitTarget]
        let model = AppModel(
            cardStore: cardStore,
            screenshotMonitor: ScreenshotMonitor(),
            attachmentStore: AttachmentStore(baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments")),
            notesExportService: NotesExportSpy(),
            suggestedTargetProvider: suggestedTargetProvider
        )

        model.beginCaptureSession()
        model.toggleCaptureSuggestedTargetChooser()
        XCTAssertTrue(model.highlightCaptureSuggestedTarget(explicitTarget))

        XCTAssertTrue(model.highlightAutomaticCaptureSuggestedTarget())
        XCTAssertEqual(model.highlightedCaptureSuggestedTarget, automaticTarget)
        XCTAssertTrue(model.isAutomaticCaptureSuggestedTargetHighlighted)
    }
}
