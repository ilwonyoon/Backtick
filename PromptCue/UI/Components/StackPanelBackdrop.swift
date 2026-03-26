import SwiftUI

// Backtick stack backdrop pattern.
// This file owns atmospheric blur, density, and edge fade for the stack panel only.
struct StackPanelBackdrop: View {
    let densityScale: Double
    let grayscaleBias: Double
    let onTap: () -> Void

    static let defaultDensityScale = StackPanelBackdropRecipe.defaultDensityScale
    static let defaultGrayscaleBias = StackPanelBackdropRecipe.defaultGrayscaleBias

    init(
        densityScale: Double = StackPanelBackdrop.defaultDensityScale,
        grayscaleBias: Double = StackPanelBackdrop.defaultGrayscaleBias,
        onTap: @escaping () -> Void = {}
    ) {
        self.densityScale = densityScale
        self.grayscaleBias = grayscaleBias
        self.onTap = onTap
    }

    var body: some View {
        backdropLayers
            .mask(StackPanelBackdropRecipe.edgeFadeMask(maskScale: maskScale))
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var backdropLayers: some View {
        // Resolve appearance at draw time via NSAppearance — never branch
        // on SwiftUI's @Environment(\.colorScheme) which can lag behind
        // the actual system appearance and contaminate child views.
        let isDark = Self.isDarkAppearance
        ZStack {
            VisualEffectBackdrop(
                material: .underWindowBackground,
                blendingMode: .behindWindow,
                appearanceName: nil
            )

            VisualEffectBackdrop(
                material: isDark ? .hudWindow : .underWindowBackground,
                blendingMode: .withinWindow,
                appearanceName: nil
            )
            .opacity(isDark
                ? StackPanelBackdropRecipe.mergedDarkDensityOpacity(densityScale)
                : StackPanelBackdropRecipe.mergedLightDensityOpacity(densityScale))
            .mask(isDark
                ? StackPanelBackdropRecipe.darkDensityMask(maskScale: maskScale)
                : StackPanelBackdropRecipe.lightDensityMask(maskScale: maskScale))

            if isDark {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.004 * atmosphereScale),
                        Color.black.opacity(0.012 * atmosphereScale),
                        Color.black.opacity(0.032 * atmosphereScale),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.012 * atmosphereScale),
                        Color.clear,
                        Color.black.opacity(0.03 * atmosphereScale),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.010 * atmosphereScale),
                        Color.white.opacity(0.006 * atmosphereScale),
                        Color.white.opacity(0.018 * atmosphereScale),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(StackPanelBackdropRecipe.lightAtmosphereMask(maskScale: maskScale))

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.014 * atmosphereScale),
                        Color.clear,
                        Color.black.opacity(0.008 * atmosphereScale),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask(StackPanelBackdropRecipe.lightAtmosphereMask(maskScale: maskScale))
            }
        }
    }

    private static var isDarkAppearance: Bool {
        NSApp.effectiveAppearance
            .bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
            .map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
    }

    private var atmosphereScale: Double {
        StackPanelBackdropRecipe.atmosphereScale(densityScale)
    }

    private var maskScale: Double {
        StackPanelBackdropRecipe.maskScale(densityScale)
    }
}
