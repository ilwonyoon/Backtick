import PromptCueCore
import SwiftUI

struct CardStackView: View {
    @ObservedObject var model: AppModel
    let onCopyCard: (CaptureCard) -> Void
    let onCopySelection: () -> Void
    let onDeleteCard: (CaptureCard) -> Void
    let onExportTodayToNotes: () -> Void

    var body: some View {
        ZStack {
            stackBackdrop

            VStack(alignment: .leading, spacing: PrimitiveTokens.Size.panelSectionSpacing) {
                header

                if model.cards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: PrimitiveTokens.Size.cardStackSpacing) {
                            ForEach(model.stackCards) { card in
                                cardRow(for: card)
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
        HStack(alignment: .center, spacing: PrimitiveTokens.Space.sm) {
            Spacer(minLength: 0)

            exportTodayButton

            if selectionMode {
                selectionHeader
            }
        }
    }

    private var exportTodayButton: some View {
        Button(action: onExportTodayToNotes) {
            PromptCueChip(
                fill: model.canExportTodayToNotes
                    ? SemanticTokens.Surface.accentFill.opacity(PrimitiveTokens.Opacity.strong)
                    : SemanticTokens.Surface.cardFill,
                border: model.canExportTodayToNotes
                    ? SemanticTokens.Border.emphasis
                    : SemanticTokens.Border.subtle
            ) {
                Label("Notes", systemImage: "note.text")
                    .font(PrimitiveTokens.Typography.chip)
                    .foregroundStyle(
                        model.canExportTodayToNotes
                            ? SemanticTokens.Text.selection
                            : SemanticTokens.Text.secondary
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!model.canExportTodayToNotes)
        .help("Export today's cards to Apple Notes")
    }

    private var selectionHeader: some View {
        HStack(alignment: .center, spacing: PrimitiveTokens.Space.xs) {
            Text("\(model.selectionCount) selected")
                .font(PrimitiveTokens.Typography.bodyStrong)
                .foregroundStyle(SemanticTokens.Text.primary)

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

    private var selectionMode: Bool {
        model.selectionCount > 0
    }

    private func cardRow(for card: CaptureCard) -> some View {
        CaptureCardView(
            card: card,
            availableSuggestedTargets: model.availableSuggestedTargets,
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
