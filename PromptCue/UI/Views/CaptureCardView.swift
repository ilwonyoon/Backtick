import SwiftUI

struct CaptureCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let card: CaptureCard
    let isSelected: Bool
    let selectionMode: Bool
    let onCopy: () -> Void
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
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
            ZStack(alignment: .topTrailing) {
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
                .padding(.trailing, actionColumnReservedWidth)
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
                .zIndex(1)
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

    private var resolvedStyle: CardActionStyle {
        CardActionStyle(
            isCardHovered: isCardHovered,
            isCopyHovered: isCopyHovered,
            isDeleteHovered: isDeleteHovered,
            isSelected: isSelected,
            isShowingCopyFeedback: isShowingCopyFeedback,
            isCopied: card.isCopied,
            selectionMode: selectionMode,
            usesPersistentActionBackdrop: usesPersistentActionBackdrop
        )
    }

    private var bodyColor: Color { resolvedStyle.bodyColor }
    private var copyIconColor: Color { resolvedStyle.copyIconColor }
    private var copyIconSystemName: String { resolvedStyle.copyIconSystemName }
    private var deleteIconColor: Color { resolvedStyle.deleteIconColor }
    private var copyIconBackground: Color { resolvedStyle.copyIconBackground }
    private var deleteIconBackground: Color { resolvedStyle.deleteIconBackground }

    private var actionColumnWidth: CGFloat {
        PrimitiveTokens.Space.xl
    }

    private var actionColumnReservedWidth: CGFloat {
        actionColumnWidth + PrimitiveTokens.Space.sm
    }

    private var usesPersistentActionBackdrop: Bool {
        colorScheme == .light && card.screenshotURL != nil
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
