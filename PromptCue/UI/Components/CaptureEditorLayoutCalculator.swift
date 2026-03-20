import AppKit
import CoreGraphics

enum CaptureEditorLayoutCalculator {
    static func editorFont(size: CGFloat = PrimitiveTokens.FontSize.capture) -> NSFont {
        let baseFont = NSFont.systemFont(ofSize: size)
        guard let fallbackFont = NSFont(name: "AppleSDGothicNeo-Regular", size: size) else {
            return baseFont
        }

        let descriptor = baseFont.fontDescriptor.addingAttributes([
            .cascadeList: [fallbackFont.fontDescriptor],
        ])
        return NSFont(descriptor: descriptor, size: size) ?? baseFont
    }

    static func lineCount(
        text: String,
        width: CGFloat,
        font: NSFont,
        lineHeight: CGFloat
    ) -> Int {
        guard !text.isEmpty else {
            return 1
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.lineBreakMode = .byWordWrapping

        let textStorage = NSTextStorage(
            attributedString: NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .paragraphStyle: paragraphStyle,
                ]
            )
        )
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: max(width, 1), height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        layoutManager.usesFontLeading = false
        layoutManager.ensureLayout(for: textContainer)

        return renderedLineCount(
            text: text,
            layoutManager: layoutManager,
            textContainer: textContainer
        )
    }

    static func measuredTextHeight(
        text: String,
        width: CGFloat,
        minimumLineHeight: CGFloat,
        font: NSFont,
        lineHeight: CGFloat
    ) -> CGFloat {
        let verticalInsetHeight = CaptureRuntimeMetrics.editorVerticalInset * 2
        let bottomBreathingRoom = CaptureRuntimeMetrics.editorBottomBreathingRoom

        guard !text.isEmpty else {
            return minimumLineHeight + verticalInsetHeight + bottomBreathingRoom
        }

        let lineCount = lineCount(
            text: text,
            width: width,
            font: font,
            lineHeight: lineHeight
        )
        let contentHeight = max(minimumLineHeight, CGFloat(lineCount) * lineHeight)
        return contentHeight + verticalInsetHeight + bottomBreathingRoom
    }

    static func metrics(
        viewportWidth: CGFloat,
        maxContentHeight: CGFloat,
        minimumLineHeight: CGFloat,
        measureHeight: (CGFloat) -> CGFloat
    ) -> CaptureEditorMetrics {
        let safeViewportWidth = max(viewportWidth, 1)
        let unconstrainedHeight = max(minimumLineHeight, ceil(measureHeight(safeViewportWidth)))
        let isScrollable = unconstrainedHeight > maxContentHeight + 0.5

        return CaptureEditorMetrics(
            contentHeight: unconstrainedHeight,
            visibleHeight: min(unconstrainedHeight, maxContentHeight),
            isScrollable: isScrollable,
            layoutWidth: safeViewportWidth
        )
    }

    static func estimatedMetrics(
        text: String,
        viewportWidth: CGFloat,
        maxContentHeight: CGFloat,
        minimumLineHeight: CGFloat,
        font: NSFont,
        lineHeight: CGFloat
    ) -> CaptureEditorMetrics {
        guard !text.isEmpty else {
            return CaptureEditorMetrics(
                contentHeight: minimumLineHeight + (CaptureRuntimeMetrics.editorVerticalInset * 2) + CaptureRuntimeMetrics.editorBottomBreathingRoom,
                visibleHeight: minimumLineHeight + (CaptureRuntimeMetrics.editorVerticalInset * 2) + CaptureRuntimeMetrics.editorBottomBreathingRoom,
                isScrollable: false,
                layoutWidth: viewportWidth
            )
        }

        return metrics(
            viewportWidth: viewportWidth,
            maxContentHeight: maxContentHeight,
            minimumLineHeight: minimumLineHeight
        ) { width in
            measuredTextHeight(
                text: text,
                width: width,
                minimumLineHeight: minimumLineHeight,
                font: font,
                lineHeight: lineHeight
            )
        }
    }

    static func renderedLineCount(
        text: String,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> Int {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var lineCount = 0
        var glyphIndex = glyphRange.location

        while glyphIndex < NSMaxRange(glyphRange) {
            var lineRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            guard lineRange.length > 0 else {
                break
            }

            lineCount += 1
            glyphIndex = NSMaxRange(lineRange)
        }

        if text.hasSuffix("\n"), !layoutManager.extraLineFragmentRect.isEmpty {
            lineCount += 1
        }

        return max(lineCount, 1)
    }
}
