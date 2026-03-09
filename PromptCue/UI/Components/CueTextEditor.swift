import AppKit
import Carbon
import SwiftUI

enum CueInlineTokenMetrics {
    static let editorHorizontalInset: CGFloat = 8
    static let editorVerticalInset: CGFloat = 6
}

enum CueEditorCommand {
    case moveSelectionUp
    case moveSelectionDown
    case completeSelection
    case cancelSelection
}

struct CueTextEditor: NSViewRepresentable {
    @Binding var text: String
    let maxContentHeight: CGFloat
    let onHeightChange: (CGFloat) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onCommand: (CueEditorCommand) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> CueEditorContainerView {
        let container = CueEditorContainerView()
        let textView = container.textView

        textView.delegate = context.coordinator
        textView.string = text
        container.maxMeasuredHeight = maxContentHeight
        container.onHeightChange = onHeightChange
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        textView.onCommand = onCommand
        configure(textView)

        DispatchQueue.main.async {
            container.window?.makeFirstResponder(textView)
        }

        return container
    }

    func updateNSView(_ container: CueEditorContainerView, context: Context) {
        let textView = container.textView

        if textView.string != text {
            textView.string = text
            container.layoutSubtreeIfNeeded()
        }

        container.maxMeasuredHeight = maxContentHeight
        container.onHeightChange = onHeightChange
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        textView.onCommand = onCommand
        configure(textView)
        requestFocusIfNeeded(in: container)
    }

    private func requestFocusIfNeeded(in container: CueEditorContainerView) {
        DispatchQueue.main.async {
            guard let window = container.window else {
                return
            }

            guard NSApp.isActive, window.isKeyWindow else {
                return
            }

            if window.firstResponder !== container.textView {
                window.makeFirstResponder(container.textView)
            }
        }
    }

    private func configure(_ textView: WrappingCueTextView) {
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        let font = NSFont.systemFont(ofSize: PrimitiveTokens.FontSize.capture)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = PrimitiveTokens.LineHeight.capture
        paragraphStyle.maximumLineHeight = PrimitiveTokens.LineHeight.capture
        textView.font = font
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.textContainerInset = NSSize(
            width: CueInlineTokenMetrics.editorHorizontalInset,
            height: CueInlineTokenMetrics.editorVerticalInset
        )
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.alignment = .left
        textView.defaultParagraphStyle = paragraphStyle
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byWordWrapping

        let editorAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle,
        ]

        textView.editorAttributes = editorAttributes
        textView.typingAttributes = editorAttributes
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CueTextEditor

        init(_ parent: CueTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? WrappingCueTextView else {
                return
            }

            if parent.text != textView.string {
                parent.text = textView.string
            }

            (textView.enclosingScrollView?.superview as? CueEditorContainerView)?.updateMeasuredHeight()
        }
    }
}

final class CueEditorContainerView: NSView {
    let scrollView = NSScrollView()
    let textView: WrappingCueTextView
    var maxMeasuredHeight: CGFloat = AppUIConstants.captureEditorMaxHeight
    var onHeightChange: ((CGFloat) -> Void)?

    override init(frame frameRect: NSRect) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textView = WrappingCueTextView(frame: .zero, textContainer: textContainer)
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        updateMeasuredHeight()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.masksToBounds = true

        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        scrollView.documentView = textView
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.wantsLayer = true
        textView.layer?.masksToBounds = true
    }

    func updateMeasuredHeight() {
        let width = scrollView.contentSize.width
        guard
            width > 0,
            let textContainer = textView.textContainer,
            let layoutManager = textView.layoutManager
        else {
            return
        }

        textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)

        let verticalInset = textView.textContainerInset.height * 2
        let lineCount = lineFragmentCount(
            using: layoutManager,
            in: textContainer
        )
        let contentHeight = max(
            PrimitiveTokens.LineHeight.capture + verticalInset,
            CGFloat(lineCount) * PrimitiveTokens.LineHeight.capture + verticalInset
        )
        let visibleHeight = min(contentHeight, maxMeasuredHeight)
        let shouldScroll = contentHeight > maxMeasuredHeight + 0.5

        scrollView.hasVerticalScroller = shouldScroll
        textView.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)
        onHeightChange?(visibleHeight)
    }

    private func lineFragmentCount(
        using layoutManager: NSLayoutManager,
        in textContainer: NSTextContainer
    ) -> Int {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.location != NSNotFound else {
            return 1
        }

        var lineCount = 0
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in
            lineCount += 1
        }

        return max(lineCount, 1)
    }
}

final class WrappingCueTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onCommand: ((CueEditorCommand) -> Bool)?
    var editorAttributes: [NSAttributedString.Key: Any] = [:]

    override var isFlipped: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch Int(event.keyCode) {
        case Int(kVK_UpArrow):
            if onCommand?(.moveSelectionUp) == true {
                return
            }
            super.keyDown(with: event)
        case Int(kVK_DownArrow):
            if onCommand?(.moveSelectionDown) == true {
                return
            }
            super.keyDown(with: event)
        case Int(kVK_Tab):
            if onCommand?(.completeSelection) == true {
                return
            }
            super.keyDown(with: event)
        case Int(kVK_Return), Int(kVK_ANSI_KeypadEnter):
            if modifiers.contains(.shift) {
                super.keyDown(with: event)
            } else {
                onSubmit?()
            }
        case Int(kVK_Escape):
            if onCommand?(.cancelSelection) == true {
                return
            }
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}
