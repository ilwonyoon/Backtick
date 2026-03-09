import SwiftUI

struct StackNotificationCardSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let isSelected: Bool
    let isEmphasized: Bool
    @ViewBuilder private var content: Content

    init(
        isSelected: Bool = false,
        isEmphasized: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isEmphasized = isEmphasized
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)

        content
            .padding(PrimitiveTokens.Size.notificationCardPadding)
            .background {
                shape
                    .fill(backgroundFill)
                    .overlay {
                        shape.fill(chromeOverlay)
                    }
                    .overlay {
                        if isEmphasized {
                            shape.fill(SemanticTokens.Surface.notificationCardHoverFill)
                        }
                    }
                    .overlay(alignment: .top) {
                        shape
                            .stroke(topHighlight, lineWidth: PrimitiveTokens.Stroke.subtle)
                            .mask(alignment: .top) {
                                Rectangle()
                                    .frame(height: PrimitiveTokens.Space.sm)
                            }
                    }
            }
            .overlay {
                shape
                    .stroke(borderColor, lineWidth: isSelected ? PrimitiveTokens.Stroke.emphasis : PrimitiveTokens.Stroke.subtle)
            }
            .clipShape(shape)
            .promptCueNotificationCardShadow()
    }

    private var backgroundFill: Color {
        if isSelected {
            return SemanticTokens.Surface.accentFill
        }

        return SemanticTokens.Surface.notificationCardFill
    }

    private var chromeOverlay: Color {
        if colorScheme == .light {
            return Color.black.opacity(0.015)
        }

        return SemanticTokens.Surface.notificationCardBackdrop
    }

    private var topHighlight: Color {
        if colorScheme == .light {
            return SemanticTokens.Border.glassHighlight.opacity(0.16)
        }

        return SemanticTokens.Border.glassHighlight.opacity(0.08)
    }

    private var borderColor: Color {
        if isSelected {
            return SemanticTokens.Border.emphasis
        }

        if isEmphasized {
            return SemanticTokens.Border.notificationCardHover
        }

        return SemanticTokens.Border.notificationCard
    }
}
