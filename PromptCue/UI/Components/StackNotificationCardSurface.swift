import AppKit
import SwiftUI

// Backtick stack-card pattern surface.
// Keep stack card chrome independent from stack backdrop ownership.
struct StackNotificationCardSurface<Content: View>: View {
    let isSelected: Bool
    let isEmphasized: Bool
    let contentPadding: EdgeInsets
    let cornerRadius: CGFloat
    @ViewBuilder private var content: Content

    init(
        isSelected: Bool = false,
        isEmphasized: Bool = false,
        contentPadding: EdgeInsets = EdgeInsets(
            top: StackLayoutMetrics.cardContentInset,
            leading: StackLayoutMetrics.cardContentInset,
            bottom: StackLayoutMetrics.cardContentInset,
            trailing: StackLayoutMetrics.cardContentInset
        ),
        cornerRadius: CGFloat = PrimitiveTokens.Radius.md,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isEmphasized = isEmphasized
        self.contentPadding = contentPadding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        let cardBody = content
            .padding(contentPadding)
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
                    .stroke(borderColor, lineWidth: isSelected ? 2.0 : PrimitiveTokens.Stroke.subtle)
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
            return SemanticTokens.Surface.notificationCardEmphasizedFill
        }

        if isEmphasized {
            return SemanticTokens.Surface.notificationCardEmphasizedFill
        }

        return SemanticTokens.Surface.notificationCardFill
    }

    private var defaultBorderColor: Color {
        SemanticTokens.adaptiveColor(
            light: NSColor.black.withAlphaComponent(0.12 * 0.92),
            dark: NSColor.white.withAlphaComponent(0.06 * 0.82)
        )
    }

    private var borderColor: Color {
        if isSelected {
            return SemanticTokens.adaptiveColor(
                light: NSColor.black.withAlphaComponent(0.5),
                dark: NSColor.white.withAlphaComponent(0.7)
            )
        }

        if isEmphasized {
            return SemanticTokens.Border.notificationCardHover
        }

        return defaultBorderColor
    }

    private var showsElevatedChrome: Bool {
        isSelected || isEmphasized
    }
}
