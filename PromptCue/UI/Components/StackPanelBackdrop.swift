import SwiftUI

// Backtick stack backdrop pattern.
// This file owns atmospheric blur, density, and edge fade for the stack panel only.
struct StackPanelBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    let densityScale: Double
    let grayscaleBias: Double

    static let defaultDensityScale = StackPanelBackdropRecipe.defaultDensityScale
    static let defaultGrayscaleBias = StackPanelBackdropRecipe.defaultGrayscaleBias

    init(
        densityScale: Double = StackPanelBackdrop.defaultDensityScale,
        grayscaleBias: Double = StackPanelBackdrop.defaultGrayscaleBias
    ) {
        self.densityScale = densityScale
        self.grayscaleBias = grayscaleBias
    }

    var body: some View {
        backdropLayers
            .mask(StackPanelBackdropRecipe.edgeFadeMask(maskScale: maskScale))
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var backdropLayers: some View {
        if colorScheme == .light {
            ZStack {
                VisualEffectBackdrop(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow,
                    appearanceName: .vibrantLight
                )

                VisualEffectBackdrop(
                    material: .underWindowBackground,
                    blendingMode: .withinWindow,
                    appearanceName: .vibrantLight
                )
                .opacity(StackPanelBackdropRecipe.primaryLightDensityOpacity(densityScale))
                .mask(StackPanelBackdropRecipe.lightDensityMask(maskScale: maskScale))

                if StackPanelBackdropRecipe.secondaryLightDensityOpacity(densityScale) > 0 {
                    VisualEffectBackdrop(
                        material: .underWindowBackground,
                        blendingMode: .withinWindow,
                        appearanceName: .vibrantLight
                    )
                    .opacity(StackPanelBackdropRecipe.secondaryLightDensityOpacity(densityScale))
                    .mask(StackPanelBackdropRecipe.lightDensityMask(maskScale: maskScale))
                }

                LinearGradient(
                    colors: [
                        StackPanelBackdropRecipe.lightTopTint.opacity(0.01 * atmosphereScale),
                        Color.clear,
                        StackPanelBackdropRecipe.lightBottomTint(grayscaleBias).opacity(0.02 * atmosphereScale),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [
                        StackPanelBackdropRecipe.lightLeadingTint(grayscaleBias).opacity(0.01 * atmosphereScale),
                        StackPanelBackdropRecipe.lightMidTint(grayscaleBias).opacity(0.03 * atmosphereScale),
                        StackPanelBackdropRecipe.lightTrailingTint(grayscaleBias).opacity(0.08 * atmosphereScale),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        } else {
            ZStack {
                VisualEffectBackdrop(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow,
                    appearanceName: .vibrantDark
                )

                VisualEffectBackdrop(
                    material: .hudWindow,
                    blendingMode: .withinWindow,
                    appearanceName: .vibrantDark
                )
                .opacity(StackPanelBackdropRecipe.primaryDarkDensityOpacity(densityScale))
                .mask(StackPanelBackdropRecipe.darkDensityMask(maskScale: maskScale))

                if StackPanelBackdropRecipe.secondaryDarkDensityOpacity(densityScale) > 0 {
                    VisualEffectBackdrop(
                        material: .hudWindow,
                        blendingMode: .withinWindow,
                        appearanceName: .vibrantDark
                    )
                    .opacity(StackPanelBackdropRecipe.secondaryDarkDensityOpacity(densityScale))
                    .mask(StackPanelBackdropRecipe.darkDensityMask(maskScale: maskScale))
                }

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.01 * atmosphereScale),
                        Color.black.opacity(0.04 * atmosphereScale),
                        Color.black.opacity(0.10 * atmosphereScale),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04 * atmosphereScale),
                        Color.clear,
                        Color.black.opacity(0.09 * atmosphereScale),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var atmosphereScale: Double {
        StackPanelBackdropRecipe.atmosphereScale(densityScale)
    }

    private var maskScale: Double {
        StackPanelBackdropRecipe.maskScale(densityScale)
    }
}
