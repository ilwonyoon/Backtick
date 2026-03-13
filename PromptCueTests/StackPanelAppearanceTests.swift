import AppKit
import PromptCueCore
import XCTest
@testable import Prompt_Cue

@MainActor
final class StackPanelAppearanceTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testInheritedThemeRefreshKeepsStackPanelFreeOfLocalOverrides() throws {
        let controller = makeController()
        controller.prepareForFirstPresentation()

        let panel = try XCTUnwrap(stackPanel(from: controller))
        panel.appearance = NSAppearance(named: .darkAqua)
        controller.refreshForInheritedAppearanceChange()

        XCTAssertEqual(panel.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        XCTAssertNil(panel.contentView?.appearance)
        XCTAssertNil(panel.contentViewController?.view.appearance)
    }

    func testInheritedThemeRefreshClearsHostedLayerContentsWhenThemeChanges() throws {
        let controller = makeController()
        controller.prepareForFirstPresentation()

        let panel = try XCTUnwrap(stackPanel(from: controller))
        panel.appearance = NSAppearance(named: .aqua)
        controller.refreshForInheritedAppearanceChange()
        let hostedView = try XCTUnwrap(hostedSwiftUIView(in: panel.contentViewController?.view))
        hostedView.wantsLayer = true
        hostedView.layer?.contents = NSImage(size: NSSize(width: 4, height: 4))

        panel.appearance = NSAppearance(named: .darkAqua)
        controller.refreshForInheritedAppearanceChange()

        XCTAssertNil(hostedView.layer?.contents)
        XCTAssertEqual(hostedView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        XCTAssertNil(hostedView.appearance)
    }

    private func makeController() -> StackPanelController {
        let store = CardStore(databaseURL: tempDirectoryURL.appendingPathComponent("PromptCue.sqlite"))
        let model = AppModel(
            cardStore: store,
            attachmentStore: AttachmentStore(
                baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments", isDirectory: true)
            ),
            recentScreenshotCoordinator: StackPanelAppearanceRecentScreenshotCoordinator()
        )
        model.cards = [
            CaptureCard(
                text: "Theme flip regression coverage for the stack panel should keep resting cards synced with the inherited system appearance.",
                createdAt: Date(),
                lastCopiedAt: nil,
                sortOrder: 100
            )
        ]
        return StackPanelController(model: model)
    }

    private func stackPanel(from controller: StackPanelController) -> NSPanel? {
        Mirror(reflecting: controller)
            .children
            .first { $0.label == "panel" }?
            .value as? NSPanel
    }

    private func hostedSwiftUIView(in rootView: NSView?) -> NSView? {
        guard let rootView else {
            return nil
        }

        if NSStringFromClass(type(of: rootView)).contains("NSHosting") {
            return rootView
        }

        for subview in rootView.subviews {
            if let hostedView = hostedSwiftUIView(in: subview) {
                return hostedView
            }
        }

        return nil
    }
}

@MainActor
private final class StackPanelAppearanceRecentScreenshotCoordinator: RecentScreenshotCoordinating {
    var state: RecentScreenshotState = .idle
    var onStateChange: ((RecentScreenshotState) -> Void)?

    func start() {}
    func stop() {}
    func prepareForCaptureSession() {}
    func refreshNow() {}
    func resolveCurrentCaptureAttachment(timeout: TimeInterval) async -> URL? { nil }
    func consumeCurrent() {}
    func dismissCurrent() {}
    func suspendExpiration() {}
    func resumeExpiration() {}
}
