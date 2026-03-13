import AppKit
import XCTest
@testable import Prompt_Cue

@MainActor
final class AppearanceSettingsTests: XCTestCase {
    override func tearDown() {
        NSApp.appearance = nil
        super.tearDown()
    }

    func testApplyAppearanceClearsAppAppearanceOverride() {
        let model = AppearanceSettingsModel()

        NSApp.appearance = NSAppearance(named: .darkAqua)

        model.applyAppearance()

        XCTAssertNil(NSApp.appearance)
    }

    func testApplyAppearancePublishesNilAppearance() {
        let model = AppearanceSettingsModel()
        var appliedAppearance: NSAppearance??

        model.onAppearanceApplied = { appearance in
            appliedAppearance = appearance
        }

        model.applyAppearance()

        XCTAssertNotNil(appliedAppearance)
        XCTAssertNil(appliedAppearance!)
    }

    func testRefreshThenApplyAppearanceStillPublishesInheritedSystemAppearance() {
        let model = AppearanceSettingsModel()
        var appliedAppearance: NSAppearance??

        NSApp.appearance = NSAppearance(named: .darkAqua)
        model.onAppearanceApplied = { appearance in
            appliedAppearance = appearance
        }

        model.refresh()
        model.applyAppearance()

        XCTAssertNotNil(appliedAppearance)
        XCTAssertNil(appliedAppearance!)
        XCTAssertNil(NSApp.appearance)
    }
}
