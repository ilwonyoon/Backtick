import SwiftUI

enum PromptCueChipSize {
    case regular
    case compact

    var horizontalPadding: CGFloat {
        switch self {
        case .regular:
            return PrimitiveTokens.Space.sm
        case .compact:
            return PrimitiveTokens.Space.xs
        }
    }

    var height: CGFloat {
        switch self {
        case .regular:
            return PrimitiveTokens.Size.chipHeight
        case .compact:
            return PrimitiveTokens.Size.compactChipHeight
        }
    }
}

struct PromptCueChip<Content: View>: View {
    let fill: Color
    let border: Color
    let size: PromptCueChipSize
    @ViewBuilder private var content: Content

    init(
        fill: Color = SemanticTokens.Surface.cardFill,
        border: Color = SemanticTokens.Border.subtle,
        size: PromptCueChipSize = .regular,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.border = border
        self.size = size
        self.content = content()
    }

    var body: some View {
        content
            .lineLimit(1)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(
                Capsule(style: .continuous)
                    .fill(fill)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(border)
            }
            .fixedSize(horizontal: true, vertical: false)
    }
}
