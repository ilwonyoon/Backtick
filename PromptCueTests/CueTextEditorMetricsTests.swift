import AppKit
import XCTest
@testable import Prompt_Cue

@MainActor
final class CueTextEditorMetricsTests: XCTestCase {
    private var container: CueEditorContainerView!
    private var reportedMetrics: [CaptureEditorMetrics] = []

    override func setUpWithError() throws {
        try super.setUpWithError()

        container = CueEditorContainerView()
        container.maxMeasuredHeight = CaptureRuntimeMetrics.editorMaxHeight
        container.onMetricsChange = { [weak self] metrics in
            self?.reportedMetrics.append(metrics)
        }
        applyProductionTypingStyle(to: container.textView)

        layoutEditor(width: CaptureRuntimeMetrics.editorViewportWidth)
    }

    override func tearDownWithError() throws {
        container = nil
        reportedMetrics = []
        try super.tearDownWithError()
    }

    func testEmptyEditorReportsSingleLineMinimumMetrics() {
        setText("")

        XCTAssertEqual(lastReportedMetrics.contentHeight, CaptureRuntimeMetrics.editorMinimumVisibleHeight, accuracy: 0.5)
        XCTAssertEqual(lastReportedMetrics.visibleHeight, CaptureRuntimeMetrics.editorMinimumVisibleHeight, accuracy: 0.5)
        XCTAssertFalse(lastReportedMetrics.isScrollable)
        XCTAssertFalse(container.scrollView.hasVerticalScroller)
    }

    func testWrapToTwoLinesUsesR7BVisibleHeightContract() {
        let metrics = estimatedMetrics(
            for: "Prompt Cue wraps short capture notes cleanly."
        )

        XCTAssertEqual(metrics.contentHeight, expectedVisibleHeight(forLineCount: 2), accuracy: 0.5)
        XCTAssertEqual(metrics.visibleHeight, expectedVisibleHeight(forLineCount: 2), accuracy: 0.5)
        XCTAssertFalse(metrics.isScrollable)
        XCTAssertEqual(metrics.layoutWidth, CaptureRuntimeMetrics.editorViewportWidth, accuracy: 0.5)
    }

    func testBottomBreathingRoomPersistsAcrossSingleAndTwoLineMetrics() {
        let singleLineMetrics = estimatedMetrics(for: "Quick cue.")
        let twoLineMetrics = estimatedMetrics(
            for: "Prompt Cue wraps short capture notes cleanly."
        )

        XCTAssertEqual(singleLineMetrics.visibleHeight, expectedVisibleHeight(forLineCount: 1), accuracy: 0.5)
        XCTAssertEqual(twoLineMetrics.visibleHeight, expectedVisibleHeight(forLineCount: 2), accuracy: 0.5)
        XCTAssertEqual(
            twoLineMetrics.visibleHeight - singleLineMetrics.visibleHeight,
            PrimitiveTokens.LineHeight.capture,
            accuracy: 0.5
        )
    }

    func testSingleLineKoreanKeepsMinimumVisibleHeightContract() {
        setText("한")

        XCTAssertEqual(lastReportedMetrics.contentHeight, CaptureRuntimeMetrics.editorMinimumVisibleHeight, accuracy: 0.5)
        XCTAssertEqual(lastReportedMetrics.visibleHeight, CaptureRuntimeMetrics.editorMinimumVisibleHeight, accuracy: 0.5)
        XCTAssertFalse(lastReportedMetrics.isScrollable)
        XCTAssertEqual(firstLineFragmentHeight(), PrimitiveTokens.LineHeight.capture, accuracy: 0.1)
    }

    func testMarkedTextFromEmptyEditorKeepsMinimumVisibleHeightContract() {
        container.textView.setMarkedText(
            "한",
            selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: 0, length: 0)
        )
        container.updateMeasuredMetrics(forceMeasure: true)
        drainMainQueue()

        XCTAssertTrue(container.textView.hasMarkedText())
        XCTAssertEqual(lastReportedMetrics.contentHeight, CaptureRuntimeMetrics.editorMinimumVisibleHeight, accuracy: 0.5)
        XCTAssertEqual(lastReportedMetrics.visibleHeight, CaptureRuntimeMetrics.editorMinimumVisibleHeight, accuracy: 0.5)
        XCTAssertFalse(lastReportedMetrics.isScrollable)
    }

    func testAppendingSpaceToSingleHangulGlyphKeepsBaselineStable() {
        setText("한")
        let glyphYBeforeSpace = firstGlyphLocationY()

        setText("한 ")
        let glyphYAfterSpace = firstGlyphLocationY()

        XCTAssertEqual(glyphYBeforeSpace, glyphYAfterSpace, accuracy: 0.1)
    }

    func testPastePayloadGrowsToCapBeforeScrollerTurnsOn() {
        layoutEditor(width: CaptureRuntimeMetrics.editorViewportWidth)

        setText(multilinePaste(lineCount: 6), forceScrollToSelection: true)

        XCTAssertEqual(lastReportedMetrics.visibleHeight, expectedVisibleHeight(forLineCount: 6), accuracy: 1)
        XCTAssertFalse(lastReportedMetrics.isScrollable)
        XCTAssertFalse(container.scrollView.hasVerticalScroller)

        setText(multilinePaste(lineCount: 7), forceScrollToSelection: true)

        XCTAssertEqual(lastReportedMetrics.visibleHeight, CaptureRuntimeMetrics.editorMaxHeight, accuracy: 1)
        XCTAssertTrue(lastReportedMetrics.isScrollable)
        XCTAssertFalse(container.scrollView.hasVerticalScroller)
        XCTAssertGreaterThan(lastReportedMetrics.contentHeight, CaptureRuntimeMetrics.editorMaxHeight)
        XCTAssertGreaterThan(container.textView.frame.height, lastReportedMetrics.visibleHeight)
    }

    func testLargePasteUsesReservedScrollerWidthAfterCrossingCap() {
        layoutEditor(width: CaptureRuntimeMetrics.editorViewportWidth)
        setText(multilinePaste(lineCount: 12), forceScrollToSelection: true)

        XCTAssertTrue(lastReportedMetrics.isScrollable)
        XCTAssertEqual(lastReportedMetrics.visibleHeight, CaptureRuntimeMetrics.editorMaxHeight, accuracy: 1)
        XCTAssertGreaterThan(lastReportedMetrics.contentHeight, lastReportedMetrics.visibleHeight)
        XCTAssertEqual(lastReportedMetrics.layoutWidth, CaptureRuntimeMetrics.editorViewportWidth, accuracy: 1)
    }

    func testNarrowerWidthIncreasesMeasuredVisibleHeightForSameContent() {
        let text = "This contract should fail if a future rewrite stops measuring wrapped text against the available width."

        layoutEditor(width: 360)
        setText(text)
        let wideMetrics = lastReportedMetrics

        layoutEditor(width: 220)
        setText(text)
        let narrowMetrics = lastReportedMetrics

        XCTAssertGreaterThan(narrowMetrics.visibleHeight, wideMetrics.visibleHeight)
    }

    func testRefreshAppearanceReappliesResolvedEditorColorsForThemeChanges() {
        setText("Theme sync")

        let lightAppearance = NSAppearance(named: .aqua)!
        container.appearance = lightAppearance
        container.refreshAppearance()
        let lightTextColor = currentForegroundColor()
        let expectedLightTextColor = resolvedLabelColor(for: lightAppearance)

        let darkAppearance = NSAppearance(named: .darkAqua)!
        container.appearance = darkAppearance
        container.refreshAppearance()
        let darkTextColor = currentForegroundColor()
        let expectedDarkTextColor = resolvedLabelColor(for: darkAppearance)

        XCTAssertEqual(lightTextColor, expectedLightTextColor)
        XCTAssertEqual(darkTextColor, expectedDarkTextColor)
        XCTAssertNotEqual(lightTextColor, darkTextColor)
    }

    private func estimatedMetrics(for text: String) -> CaptureEditorMetrics {
        CaptureEditorLayoutCalculator.estimatedMetrics(
            text: text,
            viewportWidth: CaptureRuntimeMetrics.editorViewportWidth,
            maxContentHeight: CaptureRuntimeMetrics.editorMaxHeight,
            minimumLineHeight: PrimitiveTokens.LineHeight.capture,
            font: CaptureEditorLayoutCalculator.editorFont(),
            lineHeight: PrimitiveTokens.LineHeight.capture
        )
    }

    private func expectedVisibleHeight(forLineCount lineCount: Int) -> CGFloat {
        (CGFloat(lineCount) * PrimitiveTokens.LineHeight.capture)
            + (CaptureRuntimeMetrics.editorVerticalInset * 2)
            + CaptureRuntimeMetrics.editorBottomBreathingRoom
    }

    private func multilinePaste(lineCount: Int) -> String {
        (1...lineCount)
            .map { "Paste line \($0) for Prompt Cue capture QA." }
            .joined(separator: "\n")
    }

    private var lastReportedMetrics: CaptureEditorMetrics {
        reportedMetrics.last ?? .empty
    }

    private func layoutEditor(width: CGFloat) {
        container.frame = NSRect(x: 0, y: 0, width: width, height: 320)
        container.needsLayout = true
        container.layoutSubtreeIfNeeded()
        container.updateMeasuredMetrics(forceMeasure: true)
        drainMainQueue()
    }

    private func setText(_ text: String, forceScrollToSelection: Bool = false) {
        container.textView.string = text
        container.textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
        applyProductionTypingStyle(to: container.textView)
        container.updateMeasuredMetrics(forceScrollToSelection: forceScrollToSelection, forceMeasure: true)
        drainMainQueue()
    }

    private func currentForegroundColor() -> NSColor? {
        container.textView.textStorage?.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
    }

    private func firstLineFragmentHeight() -> CGFloat {
        guard let layoutManager = container.textView.layoutManager,
              let textContainer = container.textView.textContainer,
              container.textView.string.isEmpty == false else {
            return 0
        }

        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).height
    }

    private func firstGlyphLocationY() -> CGFloat {
        guard let layoutManager = container.textView.layoutManager,
              let textContainer = container.textView.textContainer,
              container.textView.string.isEmpty == false else {
            return 0
        }

        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.location(forGlyphAt: 0).y
    }

    private func resolvedLabelColor(for appearance: NSAppearance) -> NSColor {
        var resolved = NSColor.labelColor
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor.labelColor.usingColorSpace(.deviceRGB) ?? NSColor.labelColor
        }
        return resolved
    }

    private func applyProductionTypingStyle(to textView: WrappingCueTextView) {
        let font = CaptureEditorLayoutCalculator.editorFont()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = PrimitiveTokens.LineHeight.capture
        paragraphStyle.maximumLineHeight = PrimitiveTokens.LineHeight.capture

        textView.font = font
        textView.defaultParagraphStyle = paragraphStyle
        textView.textContainerInset = NSSize(
            width: 0,
            height: CaptureRuntimeMetrics.editorVerticalInset
        )
        textView.layoutManager?.usesFontLeading = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle,
        ]

        if let textStorage = textView.textStorage, textStorage.length > 0 {
            textStorage.beginEditing()
            textStorage.addAttributes(
                [
                    .font: font,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraphStyle,
                ],
                range: NSRange(location: 0, length: textStorage.length)
            )
            textStorage.endEditing()
        }
    }

    private func drainMainQueue(seconds: TimeInterval = 0.05) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}
