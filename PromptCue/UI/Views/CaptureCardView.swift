import AppKit
import PromptCueCore
import SwiftUI

struct CaptureCardView: View {
    let card: CaptureCard
    let availableSuggestedTargets: [CaptureSuggestedTarget]
    let automaticSuggestedTarget: CaptureSuggestedTarget?
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

    init(
        card: CaptureCard,
        availableSuggestedTargets: [CaptureSuggestedTarget] = [],
        automaticSuggestedTarget: CaptureSuggestedTarget? = nil,
        isSelected: Bool,
        selectionMode: Bool,
        onCopy: @escaping () -> Void,
        onToggleSelection: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRefreshSuggestedTargets: @escaping () -> Void = {},
        onAssignSuggestedTarget: @escaping (CaptureSuggestedTarget) -> Void = { _ in }
    ) {
        self.card = card
        self.availableSuggestedTargets = availableSuggestedTargets
        self.automaticSuggestedTarget = automaticSuggestedTarget
        self.isSelected = isSelected
        self.selectionMode = selectionMode
        self.onCopy = onCopy
        self.onToggleSelection = onToggleSelection
        self.onDelete = onDelete
        self.onRefreshSuggestedTargets = onRefreshSuggestedTargets
        self.onAssignSuggestedTarget = onAssignSuggestedTarget
    }

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

                        Text(card.text)
                            .font(PrimitiveTokens.Typography.body)
                            .foregroundStyle(bodyColor)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(PrimitiveTokens.Space.xxxs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    SuggestedTargetOriginButton(
                        currentTarget: card.suggestedTarget,
                        availableTargets: availableSuggestedTargets,
                        emptyLabel: "Choose terminal origin",
                        onRefreshTargets: onRefreshSuggestedTargets,
                        onSelectTarget: onAssignSuggestedTarget,
                        automaticTarget: automaticSuggestedTarget
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
            .onTapGesture(perform: performPrimaryAction)
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

struct SuggestedTargetOriginButton: View {
    let currentTarget: CaptureSuggestedTarget?
    let availableTargets: [CaptureSuggestedTarget]
    let emptyLabel: String
    let onRefreshTargets: () -> Void
    let onSelectTarget: (CaptureSuggestedTarget) -> Void
    let automaticTarget: CaptureSuggestedTarget?
    let isAutomaticSelectionActive: Bool
    let onUseAutomaticTarget: (() -> Void)?
    let onActivateInlineChooser: (() -> Void)?

    @State private var isPopoverPresented = false

    init(
        currentTarget: CaptureSuggestedTarget?,
        availableTargets: [CaptureSuggestedTarget],
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
            HStack(alignment: .center, spacing: PrimitiveTokens.Space.xxxs + 3) {
                Image(nsImage: SuggestedTargetIconProvider.icon(for: displayedTarget?.bundleIdentifier ?? SuggestedTargetIconProvider.defaultBundleIdentifier))
                    .resizable()
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(primaryLabel)
                    .font(.system(size: PrimitiveTokens.FontSize.meta, weight: .medium))
                    .foregroundStyle(SemanticTokens.Text.secondary.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let secondaryLabel {
                    Text("· \(secondaryLabel)")
                        .font(.system(size: PrimitiveTokens.FontSize.micro, weight: .regular))
                        .foregroundStyle(SemanticTokens.Text.secondary.opacity(0.62))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SemanticTokens.Text.secondary.opacity(0.5))
            }
            .padding(.horizontal, PrimitiveTokens.Space.xs + 1)
            .padding(.vertical, PrimitiveTokens.Space.xxxs + 3)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.045))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.42))
                    }
            }
        }
        .buttonStyle(.plain)
        .help(currentTargetTooltip)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            SuggestedTargetChooserListView(
                selectedTarget: currentTarget ?? automaticTarget,
                highlightedTarget: currentTarget ?? automaticTarget,
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

    private var displayedTarget: CaptureSuggestedTarget? {
        currentTarget ?? automaticTarget ?? availableTargets.first
    }

    private var primaryLabel: String {
        displayedTarget?.workspaceLabel ?? emptyLabel
    }

    private var secondaryLabel: String? {
        guard let displayedTarget else {
            return nil
        }

        if let shortBranchLabel = displayedTarget.shortBranchLabel,
           shortBranchLabel.localizedCaseInsensitiveCompare(displayedTarget.workspaceLabel) != .orderedSame {
            return shortBranchLabel
        }

        return nil
    }

    private var currentTargetTooltip: String {
        guard let displayedTarget else {
            return emptyLabel
        }

        if let debugDetailText = displayedTarget.debugDetailText {
            return "\(displayedTarget.workspaceLabel)\n\(displayedTarget.chooserSecondaryLabel)\n\(debugDetailText)"
        }

        return "\(displayedTarget.workspaceLabel)\n\(displayedTarget.chooserSecondaryLabel)"
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
    static let defaultBundleIdentifier = "com.apple.Terminal"
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
