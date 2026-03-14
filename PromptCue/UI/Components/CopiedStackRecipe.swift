import AppKit
import SwiftUI

// Backtick copied-stack recipe.
// Owns the collapsed copied-section plate math so CardStackView can compose it
// without carrying local opacity and shade decisions inline.
//
// All colors are adaptive — they resolve at draw time via NSColor's
// appearance callback, eliminating dependence on SwiftUI's
// @Environment(\.colorScheme) propagation.
enum CopiedStackRecipe {
    static func collapsedBackPlateIndices(for cardCount: Int) -> [Int] {
        switch cardCount {
        case ...1:
            return []
        case 2:
            return [1]
        default:
            return [2, 1]
        }
    }

    static func collapsedBottomPadding(for indices: [Int]) -> CGFloat {
        CGFloat(indices.max() ?? 0) * PrimitiveTokens.Space.xs + PrimitiveTokens.Space.sm
    }

    static let headerTextColor = SemanticTokens.adaptiveColor(
        light: NSColor.labelColor.withAlphaComponent(0.74),
        dark: NSColor.secondaryLabelColor.withAlphaComponent(0.78)
    )

    static let previewTextColor = SemanticTokens.adaptiveColor(
        light: NSColor.labelColor.withAlphaComponent(0.78),
        dark: NSColor.secondaryLabelColor.withAlphaComponent(0.62)
    )

    // Returns the full border color (base × per-index opacity baked in)
    // so callers no longer need to combine a base token with a separate opacity.
    static func backPlateBorder(index: Int) -> Color {
        let (lightOpacity, darkOpacity): (CGFloat, CGFloat)
        switch index {
        case 1: (lightOpacity, darkOpacity) = (0.32, 0.34)
        case 2: (lightOpacity, darkOpacity) = (0.24, 0.26)
        default: (lightOpacity, darkOpacity) = (0.20, 0.22)
        }
        return SemanticTokens.adaptiveColor(
            light: NSColor.black.withAlphaComponent(0.12 * lightOpacity),
            dark: NSColor.white.withAlphaComponent(0.06 * darkOpacity)
        )
    }

    // Returns the full fill color (base × per-index opacity baked in).
    static func backPlateFill(index: Int) -> Color {
        let (lightOpacity, darkOpacity): (CGFloat, CGFloat)
        switch index {
        case 1: (lightOpacity, darkOpacity) = (0.26, 0.56)
        case 2: (lightOpacity, darkOpacity) = (0.20, 0.46)
        default: (lightOpacity, darkOpacity) = (0.18, 0.40)
        }
        return SemanticTokens.adaptiveColor(
            light: NSColor.windowBackgroundColor.withAlphaComponent(0.70 * lightOpacity),
            dark: NSColor(calibratedWhite: 0.10, alpha: 0.96 * darkOpacity)
        )
    }

    static func backPlateShade(index: Int) -> Color {
        let (lightOpacity, darkOpacity): (CGFloat, CGFloat)
        switch index {
        case 1: (lightOpacity, darkOpacity) = (0.02, 0.14)
        case 2: (lightOpacity, darkOpacity) = (0.04, 0.22)
        default: (lightOpacity, darkOpacity) = (0.05, 0.26)
        }
        return SemanticTokens.adaptiveColor(
            light: NSColor.black.withAlphaComponent(lightOpacity),
            dark: NSColor.black.withAlphaComponent(darkOpacity)
        )
    }
}
