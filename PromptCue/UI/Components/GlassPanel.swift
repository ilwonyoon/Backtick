import SwiftUI

enum GlassPanelStyle {
    case quiet
    case showcase
}

struct GlassPanel<Content: View>: View {
    let padding: CGFloat
    let style: GlassPanelStyle
    @ViewBuilder private var content: Content
    private let shape = RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.xl, style: .continuous)

    init(
        padding: CGFloat = PrimitiveTokens.Size.panelPadding,
        style: GlassPanelStyle = .quiet,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                backgroundSurface
            }
            .overlay {
                borderSurface
            }
            .modifier(shadowModifier)
    }

    @ViewBuilder
    private var backgroundSurface: some View {
        switch style {
        case .quiet:
            shape
                .fill(SemanticTokens.MaterialStyle.floatingShell)
                .overlay {
                    shape.fill(SemanticTokens.Surface.panelFill)
                }
        case .showcase:
            shape
                .fill(SemanticTokens.MaterialStyle.floatingShell)
                .overlay {
                    shape.fill(SemanticTokens.Surface.panelFill)
                }
                .overlay {
                    shape.fill(ShowcaseGlassChrome.gradientOverlay)
                }
        }
    }

    @ViewBuilder
    private var borderSurface: some View {
        switch style {
        case .quiet:
            shape.stroke(SemanticTokens.Border.subtle)
        case .showcase:
            shape
                .stroke(SemanticTokens.Border.subtle)
                .overlay {
                    shape
                        .inset(by: PrimitiveTokens.Stroke.subtle)
                        .stroke(ShowcaseGlassChrome.innerStroke)
                }
                .overlay(alignment: .top) {
                    TopEdgeStrokeOverlay(
                        shape: shape,
                        color: ShowcaseGlassChrome.topHighlight,
                        lineWidth: PrimitiveTokens.Stroke.subtle,
                        frameHeight: PrimitiveTokens.Space.xxl + PrimitiveTokens.Space.lg,
                        maskHeight: PrimitiveTokens.Space.xxl + PrimitiveTokens.Space.md
                    )
                }
        }
    }

    private var shadowModifier: some ViewModifier {
        ShadowStyleModifier(style: style)
    }
}

private struct ShadowStyleModifier: ViewModifier {
    let style: GlassPanelStyle

    func body(content: Content) -> some View {
        switch style {
        case .quiet:
            content.promptCuePanelShadow()
        case .showcase:
            content.promptCueGlassShadow()
        }
    }
}
