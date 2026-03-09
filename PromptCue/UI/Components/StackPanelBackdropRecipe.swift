import SwiftUI

// Backtick stack backdrop recipe.
// Owns density, grayscale, mask, and tint math so StackPanelBackdrop remains a
// pure composition surface.
enum StackPanelBackdropRecipe {
    static let defaultDensityScale = 4.0
    static let defaultGrayscaleBias = 2.0

    static func normalizedDensity(_ densityScale: Double) -> Double {
        min(4, max(0.1, densityScale))
    }

    static func grayscaleClamped(_ grayscaleBias: Double) -> Double {
        min(2, max(0, grayscaleBias))
    }

    static func primaryLightDensityOpacity(_ densityScale: Double) -> Double {
        let density = normalizedDensity(densityScale)
        return min(1, 0.36 + (density * 0.34))
    }

    static func secondaryLightDensityOpacity(_ densityScale: Double) -> Double {
        let density = normalizedDensity(densityScale)
        return min(0.78, max(0, (density - 1) * 0.62))
    }

    static func primaryDarkDensityOpacity(_ densityScale: Double) -> Double {
        let density = normalizedDensity(densityScale)
        return min(1, 0.42 + (density * 0.40))
    }

    static func secondaryDarkDensityOpacity(_ densityScale: Double) -> Double {
        let density = normalizedDensity(densityScale)
        return min(0.88, max(0, (density - 1) * 0.70))
    }

    static func atmosphereScale(_ densityScale: Double) -> Double {
        let density = normalizedDensity(densityScale)
        return min(1.8, max(0.4, 0.55 + (density * 0.45)))
    }

    static func maskScale(_ densityScale: Double) -> Double {
        let density = normalizedDensity(densityScale)
        return min(1, max(0.12, 0.18 + (density * 0.32)))
    }

    static func lightLeadingTint(_ grayscaleBias: Double) -> Color {
        Color(white: min(1, 0.90 + (grayscaleClamped(grayscaleBias) * 0.10)))
    }

    static func lightMidTint(_ grayscaleBias: Double) -> Color {
        Color(white: min(1, 0.84 + (grayscaleClamped(grayscaleBias) * 0.14)))
    }

    static func lightTrailingTint(_ grayscaleBias: Double) -> Color {
        Color(white: min(1, 0.74 + (grayscaleClamped(grayscaleBias) * 0.22)))
    }

    static var lightTopTint: Color {
        Color(white: 0.98)
    }

    static func lightBottomTint(_ grayscaleBias: Double) -> Color {
        Color(white: min(1, 0.42 + (grayscaleClamped(grayscaleBias) * 0.29)))
    }

    static func lightDensityMask(maskScale: Double) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.04 * maskScale), location: 0.18),
                .init(color: .white.opacity(0.22 * maskScale), location: 0.42),
                .init(color: .white.opacity(0.62 * maskScale), location: 0.74),
                .init(color: .white, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func darkDensityMask(maskScale: Double) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.12 * maskScale), location: 0.22),
                .init(color: .white.opacity(0.58 * maskScale), location: 0.56),
                .init(color: .white, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func edgeFadeMask(maskScale: Double) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.06 * maskScale), location: 0.16),
                .init(color: .white.opacity(0.28 * maskScale), location: 0.38),
                .init(color: .white.opacity(0.70 * maskScale), location: 0.66),
                .init(color: .white, location: 0.82),
                .init(color: .white, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

