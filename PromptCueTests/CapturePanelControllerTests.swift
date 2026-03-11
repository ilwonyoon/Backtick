import AppKit
import XCTest
@testable import Prompt_Cue

final class CapturePanelControllerTests: XCTestCase {
    func testSuggestedTargetPanelFrameKeepsTransparentInsetAboveCaptureShell() {
        let captureFrame = NSRect(x: 120, y: 220, width: PanelMetrics.capturePanelWidth, height: 240)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let chooserSize = NSSize(width: PanelMetrics.capturePanelWidth, height: 304)

        let frame = CaptureSuggestedTargetPanelLayout.frame(
            above: captureFrame,
            visibleFrame: visibleFrame,
            panelSize: chooserSize
        )

        XCTAssertGreaterThanOrEqual(
            frame.minY,
            CaptureSuggestedTargetPanelLayout.captureShellTopY(for: captureFrame)
        )
    }

    func testSuggestedTargetPanelFramePreservesShellSpacing() {
        let captureFrame = NSRect(x: 120, y: 220, width: PanelMetrics.capturePanelWidth, height: 240)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let chooserSize = NSSize(width: PanelMetrics.capturePanelWidth, height: 304)

        let frame = CaptureSuggestedTargetPanelLayout.frame(
            above: captureFrame,
            visibleFrame: visibleFrame,
            panelSize: chooserSize
        )
        let chooserShellBottomY = frame.minY + AppUIConstants.captureChooserPanelShadowBottomInset
        let expectedShellBottomY = CaptureSuggestedTargetPanelLayout.captureShellTopY(for: captureFrame)
            + AppUIConstants.captureChooserPanelVerticalSpacing

        XCTAssertEqual(chooserShellBottomY, expectedShellBottomY, accuracy: 0.001)
    }
}
