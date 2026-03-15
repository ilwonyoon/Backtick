import AppKit
import SwiftUI

// Shared notification-card chrome recipe.
// Reused by both generic notification surfaces and the Backtick stack-card surface.
//
// All colors are adaptive — they resolve at draw time via NSColor's
// appearance callback, eliminating dependence on SwiftUI's
// @Environment(\.colorScheme) propagation.
enum NotificationCardChromeRecipe {
    static let overlayFill = SemanticTokens.adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.015),
        dark: NSColor.white.withAlphaComponent(0.006)
    )

    static let topHighlight = SemanticTokens.adaptiveColor(
        light: NSColor.white.withAlphaComponent(0.52 * 0.16),
        dark: NSColor.white.withAlphaComponent(0.44 * 0.08)
    )

    static let genericTopHighlight = SemanticTokens.adaptiveColor(
        light: NSColor.white.withAlphaComponent(0.52 * 0.18),
        dark: NSColor.white.withAlphaComponent(0.44 * 0.08)
    )
}
