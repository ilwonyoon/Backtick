import AppKit
import PromptCueCore
import SwiftUI

struct CaptureSuggestedTargetAccessoryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SuggestedTargetOriginControl(
            currentTarget: model.captureChooserTarget,
            availableTargets: model.availableSuggestedTargets,
            emptyLabel: "Choose working app",
            onRefreshTargets: model.refreshAvailableSuggestedTargets,
            onSelectTarget: model.chooseDraftSuggestedTarget,
            automaticTarget: model.automaticSuggestedTarget,
            isAutomaticSelectionActive: model.isCaptureSuggestedTargetAutomatic,
            onUseAutomaticTarget: model.clearDraftSuggestedTargetOverride,
            onActivateInlineChooser: nil,
            controlWidth: AppUIConstants.captureSelectorControlWidth
        )
        .frame(
            maxWidth: .infinity,
            minHeight: AppUIConstants.captureDebugLineHeight,
            alignment: .leading
        )
    }
}

struct CaptureCardSuggestedTargetAccessoryView: View {
    let currentTarget: CaptureSuggestedTarget?
    let availableTargets: [CaptureSuggestedTarget]
    let automaticTarget: CaptureSuggestedTarget?
    let onRefreshTargets: () -> Void
    let onAssignTarget: (CaptureSuggestedTarget) -> Void

    var body: some View {
        SuggestedTargetOriginControl(
            currentTarget: currentTarget,
            availableTargets: availableTargets,
            emptyLabel: "Choose working app",
            onRefreshTargets: onRefreshTargets,
            onSelectTarget: onAssignTarget,
            automaticTarget: automaticTarget,
            isAutomaticSelectionActive: false,
            onUseAutomaticTarget: nil,
            onActivateInlineChooser: nil,
            controlWidth: nil
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CaptureSuggestedTargetChooserPanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SuggestedTargetChooserListView(
            selectedTarget: model.captureChooserTarget ?? model.availableSuggestedTargets.first,
            highlightedTarget: nil,
            availableTargets: model.availableSuggestedTargets,
            emptyLabel: "No open supported apps",
            automaticTarget: model.automaticSuggestedTarget,
            isAutomaticSelectionActive: model.isCaptureSuggestedTargetAutomatic,
            isAutomaticHighlighted: false,
            onHighlightTarget: nil,
            onHighlightAutomaticTarget: nil,
            controlWidth: AppUIConstants.captureSelectorControlWidth,
            fixedWidth: nil,
            surfaceTopPadding: AppUIConstants.captureChooserSurfaceVerticalPadding,
            surfaceBottomPadding: AppUIConstants.captureChooserSurfaceVerticalPadding,
            headerTopPadding: AppUIConstants.captureChooserPromptVerticalPadding,
            headerBottomPadding: AppUIConstants.captureChooserPromptVerticalPadding,
            allowsPeekRow: false,
            onRefreshTargets: model.refreshAvailableSuggestedTargets,
            onSelectTarget: model.chooseDraftSuggestedTarget,
            onUseAutomaticTarget: model.clearDraftSuggestedTargetOverride
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SuggestedTargetOriginControl: View {
    let currentTarget: CaptureSuggestedTarget?
    let availableTargets: [CaptureSuggestedTarget]
    let emptyLabel: String
    let onRefreshTargets: () -> Void
    let onSelectTarget: (CaptureSuggestedTarget) -> Void
    let automaticTarget: CaptureSuggestedTarget?
    let isAutomaticSelectionActive: Bool
    let onUseAutomaticTarget: (() -> Void)?
    let onActivateInlineChooser: (() -> Void)?
    let controlWidth: CGFloat?

    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            if let onActivateInlineChooser {
                onActivateInlineChooser()
            } else {
                onRefreshTargets()
                isPopoverPresented = true
            }
        } label: {
            SuggestedTargetControlChrome(controlWidth: controlWidth) {
                SuggestedTargetIdentityLine(
                    target: displayedTarget,
                    fallbackLabel: emptyLabel,
                    showChevron: true
                )
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
                controlWidth: nil,
                fixedWidth: 280,
                surfaceTopPadding: AppUIConstants.captureChooserSurfaceVerticalPadding,
                surfaceBottomPadding: AppUIConstants.captureChooserSurfaceVerticalPadding,
                headerTopPadding: AppUIConstants.captureChooserPromptVerticalPadding,
                headerBottomPadding: AppUIConstants.captureChooserPromptVerticalPadding,
                allowsPeekRow: true,
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

private struct SuggestedTargetChooserListView: View {
    let selectedTarget: CaptureSuggestedTarget?
    let highlightedTarget: CaptureSuggestedTarget?
    let availableTargets: [CaptureSuggestedTarget]
    let emptyLabel: String
    let automaticTarget: CaptureSuggestedTarget?
    let isAutomaticSelectionActive: Bool
    let isAutomaticHighlighted: Bool
    let onHighlightTarget: ((CaptureSuggestedTarget) -> Void)?
    let onHighlightAutomaticTarget: (() -> Void)?
    let controlWidth: CGFloat?
    let fixedWidth: CGFloat?
    let surfaceTopPadding: CGFloat
    let surfaceBottomPadding: CGFloat
    let headerTopPadding: CGFloat
    let headerBottomPadding: CGFloat
    let allowsPeekRow: Bool
    let onRefreshTargets: () -> Void
    let onSelectTarget: (CaptureSuggestedTarget) -> Void
    let onUseAutomaticTarget: (() -> Void)?

    @State private var visibleWindowStartIndex = 0
    @State private var suppressNextAutoScroll = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppUIConstants.captureChooserPromptBottomSpacing) {
            chooserHeader
            chooserBody
        }
        .frame(width: fixedWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppUIConstants.captureChooserSurfaceHorizontalPadding)
        .padding(.top, surfaceTopPadding)
        .padding(.bottom, surfaceBottomPadding)
        .onAppear {
            onRefreshTargets()
        }
    }

    private var filteredAvailableTargets: [CaptureSuggestedTarget] {
        guard let automaticTarget else {
            return availableTargets
        }

        return availableTargets.filter {
            $0.canonicalIdentityKey != automaticTarget.canonicalIdentityKey
        }
    }

    private var displayedTargets: [CaptureSuggestedTarget] {
        if let automaticTarget {
            return [automaticTarget] + filteredAvailableTargets
        }

        return filteredAvailableTargets
    }

    private var hasAnyChoices: Bool {
        automaticTarget != nil || !filteredAvailableTargets.isEmpty
    }

    @ViewBuilder
    private var chooserBody: some View {
        if !hasAnyChoices {
            Text(emptyLabel)
                .font(PrimitiveTokens.Typography.meta)
                .foregroundStyle(SemanticTokens.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, PrimitiveTokens.Space.sm)
                .frame(height: chooserViewportHeight, alignment: .top)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppUIConstants.captureChooserSectionSpacing) {
                        ForEach(displayedTargets, id: \.canonicalIdentityKey) { target in
                            chooserRow(
                                target: target,
                                isSelected: target == selectedTarget || (isAutomaticSelectionActive && target == automaticTarget),
                                isHighlighted: target == automaticTarget
                                    ? isAutomaticHighlighted
                                    : (!isAutomaticHighlighted && target == highlightedTarget),
                                isRecent: target == automaticTarget,
                                onHoverHighlight: {
                                    suppressNextAutoScroll = true
                                    if target == automaticTarget {
                                        if let onHighlightAutomaticTarget {
                                            onHighlightAutomaticTarget()
                                        } else {
                                            onHighlightTarget?(target)
                                        }
                                    } else {
                                        onHighlightTarget?(target)
                                    }
                                }
                            ) {
                                if target == automaticTarget {
                                    if let onUseAutomaticTarget {
                                        onUseAutomaticTarget()
                                    } else {
                                        onSelectTarget(target)
                                    }
                                } else {
                                    onSelectTarget(target)
                                }
                            }
                            .id(choiceID(for: target))
                        }
                    }
                }
                .frame(height: chooserViewportHeight, alignment: .top)
                .scrollIndicators(.hidden)
                .onAppear {
                    visibleWindowStartIndex = 0
                    scrollHighlightedRowIfNeeded(using: proxy)
                }
                .onChange(of: highlightedChoiceID) { _, _ in
                    if suppressNextAutoScroll {
                        suppressNextAutoScroll = false
                        return
                    }

                    scrollHighlightedRowIfNeeded(using: proxy)
                }
            }
        }
    }

    private var chooserViewportHeight: CGFloat {
        let visibleRowUnits = AppUIConstants.captureChooserVisibleRowUnits(
            for: totalVisibleRowCount,
            allowsPeekRow: allowsPeekRow
        )
        let fullRowCount = max(Int(floor(visibleRowUnits)), 1)
        let partialRowUnits = max(visibleRowUnits - CGFloat(fullRowCount), 0)
        let interRowSpacing = AppUIConstants.captureChooserSectionSpacing

        return (CGFloat(fullRowCount) * AppUIConstants.captureChooserRowHeight)
            + (CGFloat(max(0, fullRowCount - 1)) * interRowSpacing)
            + (partialRowUnits * AppUIConstants.captureChooserRowHeight)
    }

    private var totalVisibleRowCount: Int {
        let automaticCount = automaticTarget == nil ? 0 : 1
        return automaticCount + filteredAvailableTargets.count
    }

    private var automaticChoiceID: String {
        "__automatic__"
    }

    private var highlightedChoiceID: String? {
        if isAutomaticHighlighted, automaticTarget != nil {
            return automaticChoiceID
        }

        return highlightedTarget?.canonicalIdentityKey
    }

    private var highlightedChoiceIndex: Int? {
        guard let highlightedChoiceID else {
            return nil
        }

        return displayedTargets.firstIndex { choiceID(for: $0) == highlightedChoiceID }
    }

    private var keyboardVisibleRowCapacity: Int {
        min(max(totalVisibleRowCount, 1), AppUIConstants.captureChooserMaxVisibleRows)
    }

    private var selectableTargetCount: Int {
        Set(displayedTargets.map(\.canonicalIdentityKey)).count
    }

    private func scrollHighlightedRowIfNeeded(using proxy: ScrollViewProxy) {
        guard let highlightedChoiceIndex else {
            return
        }

        let visibleCapacity = max(keyboardVisibleRowCapacity, 1)
        let maxStartIndex = max(displayedTargets.count - visibleCapacity, 0)
        let clampedVisibleStart = min(visibleWindowStartIndex, maxStartIndex)

        if highlightedChoiceIndex < clampedVisibleStart {
            visibleWindowStartIndex = highlightedChoiceIndex
            let targetID = choiceID(for: displayedTargets[highlightedChoiceIndex])
            DispatchQueue.main.async {
                proxy.scrollTo(targetID, anchor: .top)
            }
            return
        }

        if highlightedChoiceIndex >= clampedVisibleStart + visibleCapacity {
            visibleWindowStartIndex = min(highlightedChoiceIndex - visibleCapacity + 1, maxStartIndex)
            let targetID = choiceID(for: displayedTargets[highlightedChoiceIndex])
            DispatchQueue.main.async {
                proxy.scrollTo(targetID, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func chooserRow(
        target: CaptureSuggestedTarget,
        isSelected: Bool,
        isHighlighted: Bool,
        isRecent: Bool,
        onHoverHighlight: (() -> Void)?,
        action: @escaping () -> Void
    ) -> some View {
        SuggestedTargetChooserRow(
            target: target,
            controlWidth: controlWidth,
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            isRecent: isRecent,
            onHoverHighlight: onHoverHighlight,
            action: action
        )
    }

    private func choiceID(for target: CaptureSuggestedTarget) -> String {
        if target == automaticTarget {
            return automaticChoiceID
        }

        return target.canonicalIdentityKey
    }

    private var chooserHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: PrimitiveTokens.Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("For which AI workflow?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SemanticTokens.Text.primary.opacity(0.98))

                Text("\(selectableTargetCount)")
                    .font(PrimitiveTokens.Typography.meta)
                    .foregroundStyle(SemanticTokens.Text.secondary)
            }

            Spacer(minLength: PrimitiveTokens.Space.md)
        }
        .frame(height: AppUIConstants.captureChooserPromptLineHeight, alignment: .leading)
        .padding(.top, headerTopPadding)
        .padding(.bottom, headerBottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SuggestedTargetChooserRow: View {
    let target: CaptureSuggestedTarget
    let controlWidth: CGFloat?
    let isSelected: Bool
    let isHighlighted: Bool
    let isRecent: Bool
    let onHoverHighlight: (() -> Void)?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            SuggestedTargetControlChrome(
                controlWidth: controlWidth,
                minimumHeight: AppUIConstants.captureChooserRowHeight,
                backgroundFill: backgroundFill,
                borderColor: borderColor
            ) {
                SuggestedTargetIdentityLine(
                    target: target,
                    fallbackLabel: target.fallbackDisplayLabel,
                    style: .chooser,
                    showsRecent: isRecent,
                    isSelected: isSelected
                )
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            isHovered = hovered
            if hovered {
                onHoverHighlight?()
            }
        }
        .help(target.helpText)
    }

    private var backgroundFill: Color {
        if isHighlighted {
            return SemanticTokens.Surface.captureChooserRowSelectedFill
        }

        if isHovered {
            return SemanticTokens.Surface.captureChooserRowHoverFill
        }

        return SemanticTokens.Surface.captureChooserRowFill
    }

    private var borderColor: Color {
        if isHighlighted {
            return SemanticTokens.Border.captureChooserRowSelected
        }

        if isHovered {
            return SemanticTokens.Border.captureChooserRowHover
        }

        return SemanticTokens.Border.captureChooserRow
    }
}

private struct SuggestedTargetControlChrome<Content: View>: View {
    let controlWidth: CGFloat?
    let minimumHeight: CGFloat?
    let backgroundFill: Color
    let borderColor: Color
    @ViewBuilder let content: Content

    init(
        controlWidth: CGFloat?,
        minimumHeight: CGFloat? = nil,
        backgroundFill: Color = Color.black.opacity(0.045),
        borderColor: Color = Color(nsColor: .separatorColor).opacity(0.42),
        @ViewBuilder content: () -> Content
    ) {
        self.controlWidth = controlWidth
        self.minimumHeight = minimumHeight
        self.backgroundFill = backgroundFill
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, PrimitiveTokens.Space.xs + 1)
            .padding(.vertical, PrimitiveTokens.Space.xxxs + 3)
            .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .leading)
            .background {
                Capsule(style: .continuous)
                    .fill(backgroundFill)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(borderColor)
                    }
            }
            .frame(width: controlWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: controlWidth == nil ? .leading : .center)
    }
}

private struct SuggestedTargetIdentityLine: View {
    enum Style {
        case accessory
        case chooser
    }

    let target: CaptureSuggestedTarget?
    let fallbackLabel: String
    var style: Style = .accessory
    var showChevron = false
    var showsRecent = false
    var isSelected = false

    var body: some View {
        HStack(alignment: .center, spacing: PrimitiveTokens.Space.xxxs + 3) {
            Image(nsImage: SuggestedTargetIconProvider.icon(for: target?.bundleIdentifier))
                .resizable()
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(primaryLabel)
                .font(.system(size: PrimitiveTokens.FontSize.meta, weight: .medium))
                .foregroundStyle(primaryColor)
                .lineLimit(1)
                .truncationMode(.tail)

            if let secondaryLabel {
                Text("· \(secondaryLabel)")
                    .font(.system(size: PrimitiveTokens.FontSize.micro, weight: .regular))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: PrimitiveTokens.Space.xxxs)

            HStack(alignment: .center, spacing: PrimitiveTokens.Space.xxs + 1) {
                if showsRecent {
                    Text("Recent")
                        .font(.system(size: PrimitiveTokens.FontSize.micro, weight: .medium))
                        .foregroundStyle(secondaryColor)
                        .padding(.horizontal, PrimitiveTokens.Space.xs - 1)
                        .padding(.vertical, 2)
                        .background {
                            Capsule(style: .continuous)
                                .fill(recentFillColor)
                        }
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SemanticTokens.Text.accent)
                }
            }

            if showChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SemanticTokens.Text.secondary.opacity(0.5))
            }
        }
    }

    private var primaryLabel: String {
        target?.workspaceLabel ?? fallbackLabel
    }

    private var secondaryLabel: String? {
        guard let target,
              let shortBranchLabel = target.shortBranchLabel,
              shortBranchLabel.localizedCaseInsensitiveCompare(target.workspaceLabel) != .orderedSame else {
            return nil
        }

        return shortBranchLabel
    }

    private var primaryColor: Color {
        switch style {
        case .accessory:
            return SemanticTokens.Text.secondary.opacity(0.92)
        case .chooser:
            return SemanticTokens.Text.primary.opacity(0.96)
        }
    }

    private var secondaryColor: Color {
        switch style {
        case .accessory:
            return SemanticTokens.Text.secondary.opacity(0.62)
        case .chooser:
            return SemanticTokens.Text.secondary.opacity(0.82)
        }
    }

    private var recentFillColor: Color {
        switch style {
        case .accessory:
            return Color.black.opacity(0.04)
        case .chooser:
            return Color(nsColor: .controlColor).opacity(0.52)
        }
    }
}

private extension CaptureSuggestedTarget {
    var helpText: String {
        if let debugDetailText {
            return "\(workspaceLabel)\n\(chooserSecondaryLabel)\n\(debugDetailText)"
        }

        return "\(workspaceLabel)\n\(chooserSecondaryLabel)"
    }
}

@MainActor
private enum SuggestedTargetIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleIdentifier: String?) -> NSImage {
        guard let bundleIdentifier else {
            let image = NSWorkspace.shared.icon(for: .application)
            image.size = NSSize(width: 14, height: 14)
            return image
        }

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
