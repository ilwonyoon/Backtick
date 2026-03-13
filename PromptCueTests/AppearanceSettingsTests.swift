import AppKit
import XCTest
@testable import Prompt_Cue

@MainActor
final class AppearanceSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppearanceSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testResolvedAppearanceUsesInheritedAppearanceInAutoMode() {
        AppearancePreferences.save(.auto, defaults: defaults)

        XCTAssertNil(AppearancePreferences.resolvedAppearance(defaults: defaults))
    }

    func testResolvedAppearanceUsesAquaInLightMode() {
        AppearancePreferences.save(.light, defaults: defaults)

        XCTAssertEqual(
            AppearancePreferences.resolvedAppearance(defaults: defaults)?.bestMatch(from: [.aqua, .darkAqua]),
            .aqua
        )
    }

    func testResolvedAppearanceUsesDarkAquaInDarkMode() {
        AppearancePreferences.save(.dark, defaults: defaults)

        XCTAssertEqual(
            AppearancePreferences.resolvedAppearance(defaults: defaults)?.bestMatch(from: [.aqua, .darkAqua]),
            .darkAqua
        )
    }
}
