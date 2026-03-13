import AppKit
import XCTest
@testable import Prompt_Cue

@MainActor
final class CapturePanelAppearanceTests: XCTestCase {
    override func tearDown() {
        NSApp.appearance = nil
        super.tearDown()
    }

    func testInheritedThemeRefreshClearsCapturePanelLocalOverrides() throws {
        let model = AppModel()
        let controller = CapturePanelController(model: model)
        controller.show()

        defer { controller.close() }

        let panel = try XCTUnwrap(capturePanel(from: controller))
        let runtimeView = try XCTUnwrap(panel.contentViewController?.view)

        NSApp.appearance = NSAppearance(named: .darkAqua)
        panel.appearance = NSAppearance(named: .darkAqua)
        runtimeView.appearance = NSAppearance(named: .darkAqua)

        controller.refreshForInheritedAppearanceChange()

        XCTAssertNil(panel.appearance)
        XCTAssertNil(panel.contentView?.appearance)
        XCTAssertNil(runtimeView.appearance)
        XCTAssertEqual(panel.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
    }

    func testInheritedThemeRefreshClearsCaptureHostedLayerContentsWhenThemeChanges() throws {
        let model = AppModel()
        let controller = CapturePanelController(model: model)
        controller.show()

        defer { controller.close() }

        let panel = try XCTUnwrap(capturePanel(from: controller))
        let runtimeView = try XCTUnwrap(panel.contentViewController?.view)
        runtimeView.wantsLayer = true

        NSApp.appearance = NSAppearance(named: .aqua)
        controller.refreshForInheritedAppearanceChange()
        runtimeView.layer?.contents = NSImage(size: NSSize(width: 6, height: 6))

        NSApp.appearance = NSAppearance(named: .darkAqua)
        panel.appearance = NSAppearance(named: .darkAqua)
        controller.refreshForInheritedAppearanceChange()

        XCTAssertNil(panel.appearance)
        XCTAssertNil(runtimeView.layer?.contents)
        XCTAssertEqual(runtimeView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
    }

    private func capturePanel(from controller: CapturePanelController) -> NSPanel? {
        Mirror(reflecting: controller)
            .children
            .first { $0.label == "panel" }?
            .value as? NSPanel
    }
}
