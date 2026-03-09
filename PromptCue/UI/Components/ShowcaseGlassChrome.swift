import SwiftUI

// Shared showcase-glass chrome.
// Reused only where the same showcase shell treatment already exists.
enum ShowcaseGlassChrome {
    static var gradientOverlay: LinearGradient {
        LinearGradient(
            colors: [
                SemanticTokens.Surface.glassSheen,
                SemanticTokens.Surface.glassTint,
                SemanticTokens.Surface.glassEdge,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var innerStroke: Color {
        SemanticTokens.Border.glassInner
    }

    static var topHighlight: Color {
        SemanticTokens.Border.glassHighlight
    }
}

