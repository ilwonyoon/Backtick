import SwiftUI

struct CardStackView: View {
    @ObservedObject var model: AppModel
    let onCopyCard: (CaptureCard) -> Void
    let onCopySelection: () -> Void
    let onDeleteCard: (CaptureCard) -> Void
    @State private var isCopiedStackExpanded = false

    var body: some View {
        ZStack {
            stackBackdrop

            VStack(alignment: .leading, spacing: PrimitiveTokens.Size.panelSectionSpacing) {
                header

                if model.cards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: PrimitiveTokens.Size.cardStackSpacing) {
                            if !activeCards.isEmpty {
                                ForEach(activeCards) { card in
                                    cardRow(for: card)
                                }
                            }

                            if !copiedCards.isEmpty {
                                copiedSection
                            }
                        }
                        .padding(.vertical, PrimitiveTokens.Space.xxxs)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, PrimitiveTokens.Space.sm)
            .padding(.top, PrimitiveTokens.Space.sm)
            .padding(.bottom, PrimitiveTokens.Space.md)
        }
    }

    private var header: some View {
        Group {
            if selectionMode {
                selectionHeader
            }
        }
    }

    private var selectionHeader: some View {
        HStack(alignment: .center, spacing: PrimitiveTokens.Space.xs) {
            Text("\(model.selectionCount) selected")
                .font(PrimitiveTokens.Typography.bodyStrong)
                .foregroundStyle(SemanticTokens.Text.primary)

            Spacer(minLength: PrimitiveTokens.Space.xs)

            Button(action: onCopySelection) {
                PromptCueChip(
                    fill: SemanticTokens.Surface.accentFill,
                    border: SemanticTokens.Border.emphasis
                ) {
                    Text("Copy Selected")
                        .font(PrimitiveTokens.Typography.chip)
                        .foregroundStyle(SemanticTokens.Text.selection)
                }
            }
            .buttonStyle(.plain)

            Button(action: model.clearSelection) {
                PromptCueChip {
                    Text("Clear")
                        .font(PrimitiveTokens.Typography.chip)
                        .foregroundStyle(SemanticTokens.Text.primary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        CardSurface {
            Text("No cues yet")
                .font(PrimitiveTokens.Typography.body)
                .foregroundStyle(SemanticTokens.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxWidth: .infinity)
                .frame(height: PrimitiveTokens.Size.thumbnailHeight)
        }
    }

    private var activeCards: [CaptureCard] {
        model.cards.filter { !$0.isCopied }
    }

    private var copiedCards: [CaptureCard] {
        model.cards.filter(\.isCopied)
    }

    private var selectionMode: Bool {
        model.selectionCount > 0
    }

    private func cardRow(for card: CaptureCard) -> some View {
        CaptureCardView(
            card: card,
            availableSuggestedTargets: model.availableSuggestedTargets,
            automaticSuggestedTarget: model.automaticSuggestedTarget,
            isSelected: model.selectedCardIDs.contains(card.id),
            selectionMode: selectionMode,
            onCopy: {
                onCopyCard(card)
            },
            onToggleSelection: {
                model.toggleSelection(for: card)
            },
            onDelete: {
                onDeleteCard(card)
            },
            onRefreshSuggestedTargets: {
                model.refreshAvailableSuggestedTargets()
            },
            onAssignSuggestedTarget: { target in
                model.assignSuggestedTarget(target, to: card)
            }
        )
    }

    @ViewBuilder
    private var copiedSection: some View {
        if isCopiedStackExpanded {
            VStack(alignment: .leading, spacing: PrimitiveTokens.Size.cardStackSpacing) {
                copiedSectionHeader

                ForEach(copiedCards) { card in
                    cardRow(for: card)
                }
            }
            .transition(expandedCopiedSectionTransition)
        } else {
            collapsedCopiedStack
                .transition(collapsedCopiedStackTransition)
        }
    }

    private var copiedSectionHeader: some View {
        HStack(spacing: PrimitiveTokens.Space.xs) {
            Text("Copied")
                .font(PrimitiveTokens.Typography.metaStrong)
                .foregroundStyle(SemanticTokens.Text.secondary)

            Spacer(minLength: PrimitiveTokens.Space.xs)

            Image(systemName: "chevron.down")
                .font(PrimitiveTokens.Typography.chipIcon)
                .foregroundStyle(SemanticTokens.Text.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: PrimitiveTokens.Motion.standard)) {
                isCopiedStackExpanded = false
            }
        }
    }

    private var collapsedCopiedStack: some View {
        Button {
            withAnimation(.easeOut(duration: PrimitiveTokens.Motion.standard)) {
                isCopiedStackExpanded = true
            }
        } label: {
            ZStack(alignment: .top) {
                stackedBackPlate(index: 2)
                stackedBackPlate(index: 1)

                CardSurface(style: .notification) {
                    VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxs) {
                        HStack(alignment: .center, spacing: PrimitiveTokens.Space.xs) {
                            Text("Copied")
                                .font(PrimitiveTokens.Typography.metaStrong)
                                .foregroundStyle(SemanticTokens.Text.secondary)

                            Spacer(minLength: PrimitiveTokens.Space.xs)

                            Text("\(copiedCards.count)")
                                .font(PrimitiveTokens.Typography.meta)
                                .foregroundStyle(SemanticTokens.Text.secondary)
                        }

                        if let card = copiedCards.first {
                            Text(card.text)
                                .font(PrimitiveTokens.Typography.body)
                                .foregroundStyle(
                                    SemanticTokens.Text.secondary
                                        .opacity(PrimitiveTokens.Opacity.soft)
                                )
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if copiedCards.count > 1 {
                            Text("+\(copiedCards.count - 1) more")
                                .font(PrimitiveTokens.Typography.meta)
                                .foregroundStyle(SemanticTokens.Text.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, PrimitiveTokens.Space.sm)
            }
            .padding(.bottom, PrimitiveTokens.Space.sm)
        }
        .buttonStyle(.plain)
    }

    private var expandedCopiedSectionTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
    }

    private var collapsedCopiedStackTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
    }

    private func stackedBackPlate(index: Int) -> some View {
        RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
            .fill(
                SemanticTokens.Surface.notificationStackPlateBase
                    .opacity(0.56 - (Double(index) * 0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
                    .stroke(SemanticTokens.Border.notificationCard.opacity(0.72))
            }
            .frame(height: PrimitiveTokens.Size.notificationStackPlateHeight)
            .padding(.top, CGFloat(index) * PrimitiveTokens.Space.xs)
            .padding(.horizontal, CGFloat(index) * PrimitiveTokens.Space.xs)
    }

    private var stackBackdrop: some View {
        VisualEffectBackdrop(material: .hudWindow)
            .overlay {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.02),
                        Color.black.opacity(0.06),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.10), location: 0.18),
                        .init(color: .white.opacity(0.42), location: 0.46),
                        .init(color: .white.opacity(0.92), location: 0.78),
                        .init(color: .white, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .ignoresSafeArea()
    }
}
