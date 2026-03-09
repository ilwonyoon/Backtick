import AppKit
import PromptCueCore
import SwiftUI
import UniformTypeIdentifiers

struct CaptureCardView: View {
    let card: CaptureCard
    let availableSuggestedTargets: [CaptureSuggestedTarget]
    let isSelected: Bool
    let selectionMode: Bool
    let onCopy: () -> Void
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
    let onRefreshSuggestedTargets: () -> Void
    let onAssignSuggestedTarget: (CaptureSuggestedTarget) -> Void
    @State private var isCardHovered = false
    @State private var isCopyHovered = false
    @State private var isDeleteHovered = false
    @State private var isShowingCopyFeedback = false

    var body: some View {
        CardSurface(
            isSelected: isSelected,
            isEmphasized: isCardHovered || isCopyHovered || isDeleteHovered || isShowingCopyFeedback,
            style: .notification
        ) {
            HStack(alignment: .top, spacing: PrimitiveTokens.Space.sm) {
                VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxs) {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        if let screenshotURL = card.screenshotURL {
                            LocalImageThumbnail(
                                url: screenshotURL,
                                height: PrimitiveTokens.Size.notificationThumbnailHeight
                            )
                            .opacity(card.isCopied ? PrimitiveTokens.Opacity.soft : 1)
                        }

                        Text(card.bodyText)
                            .font(PrimitiveTokens.Typography.body)
                            .foregroundStyle(bodyColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        CardBodyInteractionLayer(
                            dragText: ClipboardFormatter.string(for: [card]),
                            onActivate: performPrimaryAction
                        )
                    }

                    if let suggestedTarget = card.suggestedTarget {
                        SuggestedTargetOriginButton(
                            currentTarget: suggestedTarget,
                            availableTargets: availableSuggestedTargets,
                            style: .stack,
                            emptyLabel: "Choose terminal origin",
                            onRefreshTargets: onRefreshSuggestedTargets,
                            onSelectTarget: onAssignSuggestedTarget
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(spacing: PrimitiveTokens.Space.xs) {
                    iconButton(
                        systemName: copyIconSystemName,
                        foregroundColor: copyIconColor,
                        backgroundColor: copyIconBackground,
                        action: performCopy
                    )
                    .onHover { hovered in
                        withAnimation(.easeOut(duration: PrimitiveTokens.Motion.quick)) {
                            isCopyHovered = hovered
                        }
                    }

                    iconButton(
                        systemName: "trash",
                        foregroundColor: deleteIconColor,
                        backgroundColor: deleteIconBackground,
                        action: onDelete
                    )
                    .onHover { hovered in
                        withAnimation(.easeOut(duration: PrimitiveTokens.Motion.quick)) {
                            isDeleteHovered = hovered
                        }
                    }
                }
                .frame(width: actionColumnWidth, alignment: .topTrailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { hovered in
                withAnimation(.easeOut(duration: PrimitiveTokens.Motion.quick)) {
                    isCardHovered = hovered
                }
            }
        }
    }

    private var contentSpacing: CGFloat {
        if card.screenshotURL != nil {
            return PrimitiveTokens.Space.sm
        }

        return PrimitiveTokens.Space.xxs
    }

    private var bodyColor: Color {
        if isSelected || isCardHovered || isCopyHovered || isDeleteHovered {
            return SemanticTokens.Text.primary
        }

        if card.isCopied {
            return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.soft)
        }

        return SemanticTokens.Text.primary
    }

    private var copyIconColor: Color {
        if isDeleteHovered {
            return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.subtle)
        }

        if isShowingCopyFeedback {
            return SemanticTokens.Text.primary
        }

        if isCopyHovered || (isCardHovered && !selectionMode) {
            return SemanticTokens.Text.primary
        }

        return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.soft)
    }

    private var copyIconSystemName: String {
        if isShowingCopyFeedback {
            return "checkmark"
        }

        if isCopyHovered || (isCardHovered && !selectionMode) {
            return "doc.on.doc.fill"
        }

        return "doc.on.doc"
    }

    private var deleteIconColor: Color {
        if isDeleteHovered {
            return SemanticTokens.Text.primary
        }

        if card.isCopied {
            return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.subtle)
        }

        return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.soft)
    }

    private var copyIconBackground: Color {
        if isDeleteHovered {
            return .clear
        }

        if isShowingCopyFeedback {
            return SemanticTokens.Surface.accentFill.opacity(PrimitiveTokens.Opacity.strong)
        }

        if isCopyHovered || (isCardHovered && !selectionMode) {
            return SemanticTokens.Surface.accentFill.opacity(PrimitiveTokens.Opacity.strong)
        }

        return .clear
    }

    private var deleteIconBackground: Color {
        if isDeleteHovered {
            return SemanticTokens.Surface.accentFill.opacity(PrimitiveTokens.Opacity.medium)
        }

        return .clear
    }

    private var actionColumnWidth: CGFloat {
        PrimitiveTokens.Space.xl
    }

    private func performPrimaryAction() {
        if selectionMode {
            onToggleSelection()
            return
        }

        performCopy()
    }

    private func performCopy() {
        guard !isShowingCopyFeedback else {
            return
        }

        withAnimation(.easeOut(duration: PrimitiveTokens.Motion.quick)) {
            isShowingCopyFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + PrimitiveTokens.Motion.quick) {
            onCopy()
            isShowingCopyFeedback = false
        }
    }

    @ViewBuilder
    private func iconButton(
        systemName: String,
        foregroundColor: Color,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(PrimitiveTokens.Typography.accessoryIcon)
                .foregroundStyle(foregroundColor)
                .frame(width: PrimitiveTokens.Space.lg, height: PrimitiveTokens.Space.lg)
                .background(
                    RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.sm, style: .continuous)
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CardBodyInteractionLayer: NSViewRepresentable {
    let dragText: String
    let onActivate: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onActivate: onActivate)
    }

    func makeNSView(context: Context) -> CardBodyInteractionView {
        let view = CardBodyInteractionView()
        view.dragText = dragText
        view.onActivate = context.coordinator.activate
        return view
    }

    func updateNSView(_ nsView: CardBodyInteractionView, context: Context) {
        nsView.dragText = dragText
        nsView.onActivate = context.coordinator.activate
    }

    final class Coordinator {
        let activate: () -> Void

        init(onActivate: @escaping () -> Void) {
            self.activate = onActivate
        }
    }
}

private final class CardBodyInteractionView: NSView, NSDraggingSource {
    var dragText = ""
    var onActivate: (() -> Void)?

    private var mouseDownEvent: NSEvent?
    private var didBeginDragging = false
    private let dragThreshold: CGFloat = 4

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didBeginDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent, !didBeginDragging else {
            return
        }

        let deltaX = event.locationInWindow.x - mouseDownEvent.locationInWindow.x
        let deltaY = event.locationInWindow.y - mouseDownEvent.locationInWindow.y
        let distance = hypot(deltaX, deltaY)
        guard distance >= dragThreshold else {
            return
        }

        didBeginDragging = true
        beginExternalDrag(using: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownEvent = nil
            didBeginDragging = false
        }

        guard !didBeginDragging else {
            return
        }

        onActivate?()
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    private func beginExternalDrag(using event: NSEvent) {
        let item = ClipboardFormatter.externalDragPasteboardItem(text: dragText)
        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        let previewImage = dragPreviewImage(for: dragText)
        let dragOrigin = convert(event.locationInWindow, from: nil)
        let dragFrame = NSRect(
            x: dragOrigin.x,
            y: dragOrigin.y - previewImage.size.height,
            width: previewImage.size.width,
            height: previewImage.size.height
        )

        draggingItem.setDraggingFrame(dragFrame, contents: previewImage)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    private func dragPreviewImage(for text: String) -> NSImage {
        let previewText = String(text.prefix(80))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: PrimitiveTokens.FontSize.meta, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = (previewText as NSString).size(withAttributes: attributes)
        let imageSize = NSSize(
            width: min(max(textSize.width + 20, 120), 280),
            height: 34
        )

        let image = NSImage(size: imageSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor(calibratedWhite: 0.12, alpha: 0.92).setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: imageSize),
            xRadius: 12,
            yRadius: 12
        ).fill()

        let textRect = NSRect(
            x: 10,
            y: floor((imageSize.height - textSize.height) / 2),
            width: imageSize.width - 20,
            height: textSize.height
        )
        (previewText as NSString).draw(in: textRect, withAttributes: attributes)
        return image
    }
}

struct SuggestedTargetOriginButton: View {
    enum Style {
        case capture
        case stack

        var horizontalPadding: CGFloat {
            switch self {
            case .capture:
                return PrimitiveTokens.Space.xs + 1
            case .stack:
                return PrimitiveTokens.Space.xs
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .capture:
                return PrimitiveTokens.Space.xxxs + 3
            case .stack:
                return PrimitiveTokens.Space.xxxs + 1
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .capture:
                return 14
            case .stack:
                return 14
            }
        }

        var backgroundFill: Color {
            switch self {
            case .capture:
                return Color.black.opacity(0.045)
            case .stack:
                return SemanticTokens.Surface.cardFill.opacity(PrimitiveTokens.Opacity.surface)
            }
        }

        var borderColor: Color {
            switch self {
            case .capture:
                return Color(nsColor: .separatorColor).opacity(0.42)
            case .stack:
                return SemanticTokens.Border.subtle
            }
        }

        var titleFont: Font {
            switch self {
            case .capture:
                return .system(size: PrimitiveTokens.FontSize.meta, weight: .medium)
            case .stack:
                return PrimitiveTokens.Typography.metaStrong
            }
        }

        var detailFont: Font {
            switch self {
            case .capture:
                return .system(size: PrimitiveTokens.FontSize.micro, weight: .regular)
            case .stack:
                return PrimitiveTokens.Typography.meta
            }
        }

        var titleColor: Color {
            switch self {
            case .capture:
                return SemanticTokens.Text.secondary.opacity(0.92)
            case .stack:
                return SemanticTokens.Text.primary
            }
        }

        var detailColor: Color {
            switch self {
            case .capture:
                return SemanticTokens.Text.secondary.opacity(0.62)
            case .stack:
                return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.soft)
            }
        }

        var chevronColor: Color {
            switch self {
            case .capture:
                return SemanticTokens.Text.secondary.opacity(0.5)
            case .stack:
                return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.soft)
            }
        }

        var contentSpacing: CGFloat {
            switch self {
            case .capture:
                return PrimitiveTokens.Space.xxxs + 3
            case .stack:
                return PrimitiveTokens.Space.xs
            }
        }
    }

    let currentTarget: CaptureSuggestedTarget
    let availableTargets: [CaptureSuggestedTarget]
    let style: Style
    let emptyLabel: String
    let onRefreshTargets: () -> Void
    let onSelectTarget: (CaptureSuggestedTarget) -> Void
    let automaticTarget: CaptureSuggestedTarget?
    let isAutomaticSelectionActive: Bool
    let onUseAutomaticTarget: (() -> Void)?
    let onActivateInlineChooser: (() -> Void)?

    @State private var isPopoverPresented = false

    init(
        currentTarget: CaptureSuggestedTarget,
        availableTargets: [CaptureSuggestedTarget],
        style: Style,
        emptyLabel: String,
        onRefreshTargets: @escaping () -> Void,
        onSelectTarget: @escaping (CaptureSuggestedTarget) -> Void,
        automaticTarget: CaptureSuggestedTarget? = nil,
        isAutomaticSelectionActive: Bool = false,
        onUseAutomaticTarget: (() -> Void)? = nil,
        onActivateInlineChooser: (() -> Void)? = nil
    ) {
        self.currentTarget = currentTarget
        self.availableTargets = availableTargets
        self.style = style
        self.emptyLabel = emptyLabel
        self.onRefreshTargets = onRefreshTargets
        self.onSelectTarget = onSelectTarget
        self.automaticTarget = automaticTarget
        self.isAutomaticSelectionActive = isAutomaticSelectionActive
        self.onUseAutomaticTarget = onUseAutomaticTarget
        self.onActivateInlineChooser = onActivateInlineChooser
    }

    var body: some View {
        Button {
            if let onActivateInlineChooser {
                onActivateInlineChooser()
            } else {
                onRefreshTargets()
                isPopoverPresented = true
            }
        } label: {
            HStack(alignment: .center, spacing: style.contentSpacing) {
                Image(nsImage: SuggestedTargetIconProvider.icon(for: currentTarget.bundleIdentifier))
                    .resizable()
                    .frame(width: style.iconSize, height: style.iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(currentTarget.workspaceLabel)
                    .font(style.titleFont)
                    .foregroundStyle(style.titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let shortBranchLabel = currentTarget.shortBranchLabel,
                   shortBranchLabel.localizedCaseInsensitiveCompare(currentTarget.workspaceLabel) != .orderedSame {
                    Text("· \(shortBranchLabel)")
                        .font(style.detailFont)
                        .foregroundStyle(style.detailColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(style.chevronColor)
            }
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background {
                Capsule(style: .continuous)
                    .fill(style.backgroundFill)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(style.borderColor)
                    }
            }
        }
        .buttonStyle(.plain)
        .help(currentTargetTooltip)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            SuggestedTargetChooserListView(
                selectedTarget: currentTarget,
                highlightedTarget: currentTarget,
                availableTargets: availableTargets,
                emptyLabel: emptyLabel,
                automaticTarget: automaticTarget,
                isAutomaticSelectionActive: isAutomaticSelectionActive,
                isAutomaticHighlighted: isAutomaticSelectionActive,
                onHighlightTarget: nil,
                onHighlightAutomaticTarget: nil,
                fixedWidth: 280,
                onRefreshTargets: onRefreshTargets,
                onSelectTarget: { target in
                    onSelectTarget(target)
                    isPopoverPresented = false
                },
                onUseAutomaticTarget: onUseAutomaticTarget.map { action in
                    {
                        action()
                        isPopoverPresented = false
                    }
                }
            )
        }
    }

    private var currentTargetTooltip: String {
        if let debugDetailText = currentTarget.debugDetailText {
            return "\(currentTarget.workspaceLabel)\n\(currentTarget.chooserSecondaryLabel)\n\(debugDetailText)"
        }

        return "\(currentTarget.workspaceLabel)\n\(currentTarget.chooserSecondaryLabel)"
    }
}

struct SuggestedTargetChooserListView: View {
    let selectedTarget: CaptureSuggestedTarget?
    let highlightedTarget: CaptureSuggestedTarget?
    let availableTargets: [CaptureSuggestedTarget]
    let emptyLabel: String
    let automaticTarget: CaptureSuggestedTarget?
    let isAutomaticSelectionActive: Bool
    let isAutomaticHighlighted: Bool
    let onHighlightTarget: ((CaptureSuggestedTarget) -> Void)?
    let onHighlightAutomaticTarget: (() -> Void)?
    let fixedWidth: CGFloat?
    let onRefreshTargets: () -> Void
    let onSelectTarget: (CaptureSuggestedTarget) -> Void
    let onUseAutomaticTarget: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxs) {
            Text("Working with")
                .font(.system(size: PrimitiveTokens.FontSize.meta, weight: .semibold))
                .foregroundStyle(SemanticTokens.Text.secondary)

            if let automaticTarget, let onUseAutomaticTarget {
                chooserRow(
                    target: automaticTarget,
                    title: "Recent terminal",
                    subtitle: automaticTarget.chooserSecondaryLabel,
                    isSelected: isAutomaticSelectionActive,
                    isHighlighted: isAutomaticHighlighted,
                    onHoverHighlight: onHighlightAutomaticTarget
                ) {
                    onUseAutomaticTarget()
                }
            }

            if filteredAvailableTargets.isEmpty {
                Text(emptyLabel)
                    .font(PrimitiveTokens.Typography.meta)
                    .foregroundStyle(SemanticTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, PrimitiveTokens.Space.sm)
            } else {
                ForEach(filteredAvailableTargets, id: \.choiceKey) { target in
                    chooserRow(
                        target: target,
                        title: target.workspaceLabel,
                        subtitle: target.chooserSecondaryLabel,
                        isSelected: target == selectedTarget,
                        isHighlighted: !isAutomaticHighlighted && target == highlightedTarget,
                        onHoverHighlight: {
                            onHighlightTarget?(target)
                        }
                    ) {
                        onSelectTarget(target)
                    }
                }
            }
        }
        .frame(width: fixedWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PrimitiveTokens.Space.xs)
        .padding(.vertical, PrimitiveTokens.Space.xxxs)
        .onAppear {
            onRefreshTargets()
        }
    }

    private var filteredAvailableTargets: [CaptureSuggestedTarget] {
        guard let automaticTarget else {
            return availableTargets
        }

        return availableTargets.filter { $0.choiceKey != automaticTarget.choiceKey }
    }

    @ViewBuilder
    private func chooserRow(
        target: CaptureSuggestedTarget,
        title: String,
        subtitle: String,
        isSelected: Bool,
        isHighlighted: Bool,
        onHoverHighlight: (() -> Void)?,
        action: @escaping () -> Void
    ) -> some View {
        SuggestedTargetChooserRow(
            target: target,
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            onHoverHighlight: onHoverHighlight,
            action: action
        )
    }
}

private struct SuggestedTargetChooserRow: View {
    let target: CaptureSuggestedTarget
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isHighlighted: Bool
    let onHoverHighlight: (() -> Void)?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: PrimitiveTokens.Space.xs) {
                Image(nsImage: SuggestedTargetIconProvider.icon(for: target.bundleIdentifier))
                    .resizable()
                    .frame(width: 15, height: 15)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: PrimitiveTokens.FontSize.meta, weight: .semibold))
                        .foregroundStyle(SemanticTokens.Text.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(subtitle)
                        .font(.system(size: PrimitiveTokens.FontSize.micro, weight: .regular))
                        .foregroundStyle(SemanticTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: PrimitiveTokens.Space.xs)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SemanticTokens.Text.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PrimitiveTokens.Space.sm)
            .padding(.vertical, PrimitiveTokens.Space.xs - 1)
            .background {
                RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
                    .fill(backgroundFill)
            }
            .overlay {
                if isHighlighted || isHovered {
                    RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
                        .stroke(borderColor)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            isHovered = hovered
            if hovered {
                onHoverHighlight?()
            }
        }
        .help("\(title)\n\(subtitle)")
    }

    private var backgroundFill: Color {
        if isHighlighted {
            return Color(nsColor: .controlColor).opacity(0.56)
        }

        if isHovered {
            return Color(nsColor: .controlColor).opacity(0.34)
        }

        return .clear
    }

    private var borderColor: Color {
        if isHighlighted {
            return Color(nsColor: .separatorColor).opacity(0.42)
        }

        if isHovered {
            return Color(nsColor: .separatorColor).opacity(0.28)
        }

        return .clear
    }
}

private extension CaptureSuggestedTarget {
    var choiceKey: String {
        [
            bundleIdentifier,
            sessionIdentifier ?? "",
            repositoryRoot ?? "",
            currentWorkingDirectory ?? "",
            windowTitle ?? "",
            workspaceLabel,
        ]
        .joined(separator: "|")
    }
}

@MainActor
private enum SuggestedTargetIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleIdentifier: String) -> NSImage {
        if let cached = cache[bundleIdentifier] {
            return cached
        }

        let image: NSImage
        if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            image = NSWorkspace.shared.icon(forFile: applicationURL.path)
        } else {
            image = NSWorkspace.shared.icon(for: .application)
        }

        image.size = NSSize(width: 14, height: 14)
        cache[bundleIdentifier] = image
        return image
    }
}
