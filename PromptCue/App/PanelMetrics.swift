import CoreGraphics

enum PanelMetrics {
    static let stackPanelWidth: CGFloat = 448
    static let stackPanelHorizontalPadding: CGFloat = 14
    static let stackCardColumnWidth: CGFloat = stackPanelWidth - (stackPanelHorizontalPadding * 2)
    static let stackPanelMinimumHeight: CGFloat = 360
    static let stackPanelFallbackVisibleHeight: CGFloat = 600

    static let captureSurfaceWidth: CGFloat = 400
    static let captureSurfaceInnerPadding: CGFloat = 24
    static let captureSurfaceTopPadding: CGFloat = 12
    static let captureSurfaceBottomPadding: CGFloat = 4
    static let capturePanelOuterPadding: CGFloat = 24
    static let capturePanelShadowTopInset: CGFloat = 28
    static let capturePanelShadowBottomInset: CGFloat = 42
    static let capturePanelWidth: CGFloat = 448
    static let capturePanelVerticalSpacing: CGFloat = 12
    static let capturePanelFallbackVisibleHeight: CGFloat = 240

    static let settingsPanelWidth: CGFloat = 820
    static let settingsPanelHeight: CGFloat = 660
    static let memoryWindowWidth: CGFloat = 1_040
    static let memoryWindowHeight: CGFloat = 680
    static let memoryProjectColumnMinWidth: CGFloat = 200
    static let memoryProjectColumnWidth: CGFloat = 220
    static let memoryProjectColumnMaxWidth: CGFloat = 260
    static let memoryDocumentColumnDefaultWidth: CGFloat = 196
    static let memoryDocumentColumnMinWidth: CGFloat = 176
    static let memoryDocumentColumnMaxWidth: CGFloat = 280
    static let memoryDetailMinimumWidth: CGFloat = 360
    static let memoryWindowChromeAllowance: CGFloat = 104
    static let memoryWindowMinimumWidth: CGFloat =
        memoryProjectColumnMinWidth +
        memoryDocumentColumnMinWidth +
        memoryDetailMinimumWidth +
        memoryWindowChromeAllowance
    static let memoryWindowMinimumHeight: CGFloat = 540
    static let settingsSidebarWidth: CGFloat = 220
    static let settingsLabelColumnWidth: CGFloat = 168
    static let settingsToolbarTabWidth: CGFloat = 84
    static let settingsToolbarTabHeight: CGFloat = 40
    static let settingsExportTailEditorMinHeight: CGFloat = 96
    static let settingsExportTailEditorMaxHeight: CGFloat = 132

    static let horizontalMargin: CGFloat = 24
    static let verticalMargin: CGFloat = 24
}
