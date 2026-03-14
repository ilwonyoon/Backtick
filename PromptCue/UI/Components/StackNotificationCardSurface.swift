import AppKit
import SwiftUI

// Backtick stack-card pattern surface.
// Keep stack card chrome independent from stack backdrop ownership.
struct StackNotificationCardSurface<Content: View>: View {
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

        let cardBody = content
            .padding(PrimitiveTokens.Size.notificationCardPadding)
            .background {
                shape
                    .fill(backgroundFill)
                    .overlay {
                        shape.fill(StackNotificationCardChromeRecipe.chromeOverlay)
                    }
                    .overlay {
                        shape.fill(SemanticTokens.Surface.notificationCardHoverFill)
                            .opacity(isEmphasized ? 1 : 0)
                    }
                    .overlay(alignment: .top) {
                        TopEdgeStrokeOverlay(
                            shape: shape,
                            color: StackNotificationCardChromeRecipe.topHighlight,
                            lineWidth: PrimitiveTokens.Stroke.subtle,
                            frameHeight: PrimitiveTokens.Space.sm,
                            maskHeight: PrimitiveTokens.Space.sm
                        )
                        .opacity(showsElevatedChrome ? 1 : 0)
                    }
            }
            .overlay {
                shape
                    .stroke(borderColor, lineWidth: isSelected ? PrimitiveTokens.Stroke.emphasis : PrimitiveTokens.Stroke.subtle)
            }
            .clipShape(shape)

        cardBody.shadow(
            color: showsElevatedChrome
                ? SemanticTokens.Shadow.color.opacity(PrimitiveTokens.Opacity.soft)
                : .clear,
            radius: PrimitiveTokens.Shadow.notificationCardBlur,
            x: PrimitiveTokens.Shadow.zeroX,
            y: PrimitiveTokens.Shadow.notificationCardY
        )
    }

    private var backgroundFill: Color {
        if isSelected {
            return SemanticTokens.Surface.accentFill
        }

        if isEmphasized {
            return SemanticTokens.Surface.notificationCardEmphasizedFill
        }

        return SemanticTokens.Surface.notificationCardFill
    }

    private static let defaultBorderColor = SemanticTokens.adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.12 * 0.92),
        dark: NSColor.white.withAlphaComponent(0.06 * 0.82)
    )

    private var borderColor: Color {
        if isSelected {
            return SemanticTokens.Border.emphasis
        }

        if isEmphasized {
            return SemanticTokens.Border.notificationCardHover
        }

        return Self.defaultBorderColor
    }

    private var showsElevatedChrome: Bool {
        isSelected || isEmphasized
    }
}
