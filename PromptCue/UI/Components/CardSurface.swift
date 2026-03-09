import SwiftUI

struct CardSurface<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder private var content: Content

    init(
        isSelected: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
        content
            .padding(contentPadding)
            .background(shape.fill(backgroundFill))
            .overlay {
                shape
                    .stroke(
                        borderColor,
                        lineWidth: isSelected ? PrimitiveTokens.Stroke.emphasis : PrimitiveTokens.Stroke.subtle
                    )
            }
            .clipShape(shape)
            .promptCueCardShadow()
    }

    private var contentPadding: CGFloat {
        PrimitiveTokens.Size.cardPadding
    }

    private var backgroundFill: Color {
        if isSelected {
            return SemanticTokens.Surface.accentFill
        }
        return SemanticTokens.Surface.cardFill
    }

    private var borderColor: Color {
        if isSelected {
            return SemanticTokens.Border.emphasis
        }
        return SemanticTokens.Border.subtle
    }
}
