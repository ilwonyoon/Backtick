import AppKit
import Foundation
import PromptCueCore
import XCTest
@testable import Prompt_Cue

@MainActor
final class CapturePanelRuntimeViewControllerTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var windows: [NSWindow] = []

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
        windows.removeAll()
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testExternalDraftResetCancelsPendingDraftSync() {
        let model = makeModel()
        model.draftText = "Persist me"

        let controller = CapturePanelRuntimeViewController(model: model)
        controller.loadViewIfNeeded()
        controller.view.frame = NSRect(x: 0, y: 0, width: AppUIConstants.capturePanelWidth, height: 320)
        controller.view.layoutSubtreeIfNeeded()
        controller.prepareForPresentation()

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: AppUIConstants.capturePanelWidth,
                height: controller.currentPreferredPanelHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.layoutIfNeeded()
        window.layoutIfNeeded()

        controller.debugEditorText = "Persist me"
        controller.debugScheduleDraftSync("Persist me")

        model.draftText = ""
        drainMainQueue(seconds: 0.25)

        XCTAssertEqual(model.draftText, "")
        XCTAssertEqual(controller.debugEditorText, "")
    }

    func testInlineTagGhostShowsMostCommonSuggestionForBareHash() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["hashtag"]),
                makeTaggedCard(text: "Second", tags: ["hashtag"]),
                makeTaggedCard(text: "Third", tags: ["hello"]),
            ]
        )

        let controller = makePreparedController(model: model)
        controller.debugApplyEditorText("#", selectedLocation: 1)

        XCTAssertEqual(controller.debugInlineCompletionSuffix, "hashtag")
        XCTAssertTrue(controller.debugIsInlineCompletionVisible)
    }

    func testInlineTagGhostShowsRemainingSuffixForPrefixMatch() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["hashtag_extension"]),
                makeTaggedCard(text: "Second", tags: ["hello"]),
            ]
        )

        let controller = makePreparedController(model: model)
        controller.debugApplyEditorText("#h", selectedLocation: 2)

        XCTAssertEqual(controller.debugInlineCompletionSuffix, "ashtag_extension")
        XCTAssertTrue(controller.debugIsInlineCompletionVisible)
    }

    func testInlineTagGhostStaysHiddenMidSentence() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["hello"]),
                makeTaggedCard(text: "Second", tags: ["help"]),
            ]
        )

        let controller = makePreparedController(model: model)
        let text = "Write a #he note"
        let tokenRange = (text as NSString).range(of: "#he")
        controller.debugApplyEditorText(text, selectedLocation: NSMaxRange(tokenRange))

        XCTAssertNil(controller.debugInlineCompletionSuffix)
        XCTAssertFalse(controller.debugIsInlineCompletionVisible)
    }

    func testInlineTagCompletionKeepsInlineTagInSentence() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["hello"]),
            ]
        )

        let controller = makePreparedController(model: model)
        let text = "Write a #he note"
        let tokenRange = (text as NSString).range(of: "#he")
        controller.debugApplyEditorText(text, selectedLocation: NSMaxRange(tokenRange))

        XCTAssertNil(controller.debugInlineCompletionSuffix)
        XCTAssertFalse(controller.debugIsInlineCompletionVisible)
        XCTAssertTrue(controller.debugCompleteInlineTagSelection())
        XCTAssertEqual(controller.debugEditorText, "Write a #hello note")
        XCTAssertEqual(model.draftText, "Write a #hello note")
    }

    func testInlineTagGhostStaysHiddenWhenTokenTouchesNonLatinText() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["hello"]),
            ]
        )

        let controller = makePreparedController(model: model)
        let text = "중간#he텍스트"
        let tokenRange = (text as NSString).range(of: "#he")
        controller.debugApplyEditorText(text, selectedLocation: NSMaxRange(tokenRange))

        XCTAssertNil(controller.debugInlineCompletionSuffix)
        XCTAssertFalse(controller.debugIsInlineCompletionVisible)
    }

    func testInlineTagCompletionKeepsAdjacentNonLatinText() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["hello"]),
            ]
        )

        let controller = makePreparedController(model: model)
        let text = "중간#he텍스트"
        let tokenRange = (text as NSString).range(of: "#he")
        controller.debugApplyEditorText(text, selectedLocation: NSMaxRange(tokenRange))

        XCTAssertTrue(controller.debugCompleteInlineTagSelection())
        XCTAssertEqual(controller.debugEditorText, "중간#hello텍스트")
        XCTAssertEqual(model.draftText, "중간#hello텍스트")
    }

    func testTypingHashMidSentenceDoesNotResetDraftText() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["hello"]),
            ]
        )

        let controller = makePreparedController(model: model)
        let text = "Write a note"
        let insertionLocation = (text as NSString).range(of: "note").location
        controller.debugApplyEditorText(text, selectedLocation: insertionLocation)

        controller.debugInsertText("#")
        drainMainQueue(seconds: 0.25)

        XCTAssertEqual(controller.debugEditorText, "Write a #note")
        XCTAssertEqual(model.draftText, "Write a #note")
    }

    func testTypingInlineTagMidSentencePreservesSurroundingText() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["hello"]),
            ]
        )

        let controller = makePreparedController(model: model)
        let text = "중간텍스트"
        let insertionLocation = (text as NSString).range(of: "텍스트").location
        controller.debugApplyEditorText(text, selectedLocation: insertionLocation)

        controller.debugInsertText("#he")
        drainMainQueue(seconds: 0.25)

        XCTAssertEqual(controller.debugEditorText, "중간#he텍스트")
        XCTAssertEqual(model.draftText, "중간#he텍스트")
        XCTAssertNil(controller.debugInlineCompletionSuffix)
        XCTAssertFalse(controller.debugIsInlineCompletionVisible)
    }

    func testTypingExactTagTestMidSentencePreservesExistingText() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["tag_test"]),
            ]
        )

        let controller = makePreparedController(model: model)
        let text = "alpha beta gamma"
        let insertionLocation = (text as NSString).range(of: "gamma").location
        controller.debugApplyEditorText(text, selectedLocation: insertionLocation)

        controller.debugInsertText("#tag_test ")
        drainMainQueue(seconds: 0.25)

        XCTAssertEqual(controller.debugEditorText, "alpha beta #tag_test gamma")
        XCTAssertEqual(model.draftText, "alpha beta #tag_test gamma")
        XCTAssertNil(controller.debugInlineCompletionSuffix)
        XCTAssertFalse(controller.debugIsInlineCompletionVisible)
    }

    func testMarkedTextCompositionHidesInlineCompletionGhost() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["backtick"]),
            ]
        )

        let controller = makePreparedController(model: model)
        controller.debugApplyEditorText("#", selectedLocation: 1)

        XCTAssertEqual(controller.debugInlineCompletionSuffix, "backtick")
        XCTAssertTrue(controller.debugIsInlineCompletionVisible)

        controller.debugSetMarkedText("한", selectedLocation: 1)

        XCTAssertTrue(controller.debugHasMarkedText)
        XCTAssertNil(controller.debugInlineCompletionSuffix)
        XCTAssertFalse(controller.debugIsInlineCompletionVisible)
    }

    func testKoreanIMECompositionKeepsPreferredPanelHeightStableFromPlaceholder() throws {
        let model = makeModel()
        let controller = makePreparedController(model: model)
        let initialHeight = controller.currentPreferredPanelHeight

        controller.debugSetMarkedText("한", selectedLocation: 1)
        drainMainQueue(seconds: 0.25)
        let markedHeight = controller.currentPreferredPanelHeight

        controller.debugApplyEditorText("한", selectedLocation: 1)
        drainMainQueue(seconds: 0.25)
        let committedHeight = controller.currentPreferredPanelHeight

        XCTAssertEqual(markedHeight, initialHeight, accuracy: 0.5)
        XCTAssertEqual(committedHeight, initialHeight, accuracy: 0.5)
    }

    func testPastingMixedLanguageRTFThenTypingHashPreservesText() throws {
        let model = makeModel(
            cards: [
                makeTaggedCard(text: "First", tags: ["backtick"]),
            ]
        )

        let controller = makePreparedController(model: model)
        let text = "카운트 classification quality mixed-input rubric"
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                .kern: 6,
                .obliqueness: 0.3,
            ]
        )
        let rtfData = try XCTUnwrap(
            attributedText.data(
                from: NSRange(location: 0, length: attributedText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        )

        let pasteboard = NSPasteboard.general
        let originalItems = snapshotPasteboardItems(from: pasteboard)
        defer {
            restorePasteboard(pasteboard, items: originalItems)
        }

        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setData(rtfData, forType: .rtf))

        controller.debugPasteFromPasteboard()
        drainMainQueue(seconds: 0.25)

        controller.debugInsertText("#")
        drainMainQueue(seconds: 0.25)

        XCTAssertEqual(controller.debugEditorText, text + "#")
        let attributes = controller.debugAttributes(at: 0)
        XCTAssertNotNil(attributes[.font] as? NSFont)
        XCTAssertNil(attributes[.kern])
        XCTAssertNil(attributes[.obliqueness])
    }

    private func makeModel(cards: [CaptureCard] = []) -> AppModel {
        let store = CardStore(databaseURL: tempDirectoryURL.appendingPathComponent("PromptCue.sqlite"))
        if !cards.isEmpty {
            try? store.save(cards)
        }

        return AppModel(
            cardStore: store,
            attachmentStore: AttachmentStore(
                baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments", isDirectory: true)
            ),
            recentScreenshotCoordinator: TestRuntimeRecentScreenshotCoordinator()
        )
    }

    private func makePreparedController(model: AppModel) -> CapturePanelRuntimeViewController {
        model.start()

        let controller = CapturePanelRuntimeViewController(model: model)
        controller.loadViewIfNeeded()
        controller.view.frame = NSRect(x: 0, y: 0, width: AppUIConstants.capturePanelWidth, height: 320)
        controller.view.layoutSubtreeIfNeeded()
        controller.prepareForPresentation()

        let window = TestCapturePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: AppUIConstants.capturePanelWidth,
                height: controller.currentPreferredPanelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        controller.debugMakeEditorFirstResponder()
        window.layoutIfNeeded()
        window.layoutIfNeeded()
        windows.append(window)
        return controller
    }

    private func makeTaggedCard(text: String, tags: [String]) -> CaptureCard {
        CaptureCard(
            id: UUID(),
            text: text,
            tags: tags.compactMap { CaptureTag(rawValue: $0) },
            createdAt: Date(),
            sortOrder: Date().timeIntervalSinceReferenceDate
        )
    }

    private func drainMainQueue(seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func snapshotPasteboardItems(from pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let snapshot = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    snapshot.setData(data, forType: type)
                } else if let string = item.string(forType: type) {
                    snapshot.setString(string, forType: type)
                }
            }
            return snapshot
        }
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        guard !items.isEmpty else {
            return
        }

        pasteboard.writeObjects(items)
    }
}

@MainActor
private final class TestRuntimeRecentScreenshotCoordinator: RecentScreenshotCoordinating {
    var state: RecentScreenshotState = .idle
    var onStateChange: ((RecentScreenshotState) -> Void)?

    func start() {}
    func stop() {}
    func prepareForCaptureSession() {}
    func refreshNow() {}
    func resolveCurrentCaptureAttachment(timeout: TimeInterval) async -> URL? { nil }
    func consumeCurrent() {}
    func dismissCurrent() {}
    func suspendExpiration() {}
    func resumeExpiration() {}
}

private final class TestCapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
