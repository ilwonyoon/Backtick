import SwiftUI

struct CardActionStyle {
    let isCardHovered: Bool
    let isCopyHovered: Bool
    let isDeleteHovered: Bool
    let isSelected: Bool
    let isShowingCopyFeedback: Bool
    let isCopied: Bool
    let selectionMode: Bool
    let usesPersistentActionBackdrop: Bool

    private var isAnyHovered: Bool {
        isCardHovered || isCopyHovered || isDeleteHovered
    }

    private var isCopyActive: Bool {
        isCopyHovered || (isCardHovered && !selectionMode)
    }

    var bodyColor: Color {
        if isSelected || isAnyHovered {
            return SemanticTokens.Text.primary
        }

        if isCopied {
            return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.soft)
        }

        return SemanticTokens.Text.primary
    }

    var copyIconColor: Color {
        if isDeleteHovered {
            return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.subtle)
        }

        if isShowingCopyFeedback || isCopyActive {
            return SemanticTokens.Text.primary
        }

        return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.soft)
    }

    var copyIconSystemName: String {
        if isShowingCopyFeedback {
            return "checkmark"
        }

        if isCopyActive {
            return "doc.on.doc.fill"
        }

        return "doc.on.doc"
    }

    var deleteIconColor: Color {
        if isDeleteHovered {
            return SemanticTokens.Text.primary
        }

        if isCopied {
            return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.subtle)
        }

        return SemanticTokens.Text.secondary.opacity(PrimitiveTokens.Opacity.soft)
    }

    var copyIconBackground: Color {
        if isDeleteHovered {
            return .clear
        }

        if isShowingCopyFeedback || isCopyActive {
            return SemanticTokens.Surface.accentFill.opacity(PrimitiveTokens.Opacity.strong)
        }

        if usesPersistentActionBackdrop {
            return SemanticTokens.Surface.notificationCardBackdrop.opacity(0.72)
        }

        return .clear
    }

    var deleteIconBackground: Color {
        if isDeleteHovered {
            return SemanticTokens.Surface.accentFill.opacity(PrimitiveTokens.Opacity.medium)
        }

        if usesPersistentActionBackdrop {
            return SemanticTokens.Surface.notificationCardBackdrop.opacity(0.6)
        }

        return .clear
    }
}
