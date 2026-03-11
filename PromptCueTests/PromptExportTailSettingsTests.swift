import XCTest
@testable import Prompt_Cue
import PromptCueCore

@MainActor
final class PromptExportTailSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PromptExportTailSettingsTests.\(UUID().uuidString)"
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

    func testLoadDefaultsToDisabledWithDefaultTemplate() {
        let state = PromptExportTailPreferences.load(defaults: defaults)

        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(state.suffixText, PromptExportTailPreferences.defaultSuffixText)
        XCTAssertEqual(state.exportSuffix, .off)
    }

    func testSaveRoundTripsEnabledSuffixState() {
        let expected = PromptExportTailState(
            isEnabled: true,
            suffixText: "\n\nRun root-cause analysis first.\n"
        )

        PromptExportTailPreferences.save(expected, defaults: defaults)
        let loaded = PromptExportTailPreferences.load(defaults: defaults)

        XCTAssertEqual(loaded.isEnabled, true)
        XCTAssertEqual(loaded.suffixText, expected.suffixText)
        XCTAssertEqual(
            ExportFormatter.string(
                for: [CaptureCard(text: "One", createdAt: .now)],
                suffix: loaded.exportSuffix
            ),
            """
            • One

            Run root-cause analysis first.
            """
        )
    }

    func testResetDisablesSuffixAndRestoresTemplate() {
        PromptExportTailPreferences.save(
            PromptExportTailState(isEnabled: true, suffixText: "Custom"),
            defaults: defaults
        )

        let resetState = PromptExportTailPreferences.reset(defaults: defaults)

        XCTAssertFalse(resetState.isEnabled)
        XCTAssertEqual(resetState.suffixText, PromptExportTailPreferences.defaultSuffixText)
    }

    func testClipboardFormatterSkipsExportTailForStandaloneLink() {
        let payload = ClipboardFormatter.string(
            for: [CaptureCard(text: "https://example.com/docs", createdAt: .now)],
            suffix: ExportSuffix("Run root-cause analysis first.")
        )

        XCTAssertEqual(payload, "https://example.com/docs")
    }

    func testClipboardFormatterSkipsExportTailForStandaloneSecret() {
        let payload = ClipboardFormatter.string(
            for: [CaptureCard(text: "sk-ant-abc123def456xyz987", createdAt: .now)],
            suffix: ExportSuffix("Run root-cause analysis first.")
        )

        XCTAssertEqual(payload, "sk-ant-abc123def456xyz987")
    }

    func testClipboardFormatterSkipsExportTailForStandaloneEmail() {
        let payload = ClipboardFormatter.string(
            for: [CaptureCard(text: "dev@example.com", createdAt: .now)],
            suffix: ExportSuffix("Run root-cause analysis first.")
        )

        XCTAssertEqual(payload, "dev@example.com")
    }

    func testClipboardFormatterSkipsExportTailForStandaloneLocalhostLink() {
        let payload = ClipboardFormatter.string(
            for: [CaptureCard(text: "localhost:3000/api/v1?draft=1", createdAt: .now)],
            suffix: ExportSuffix("Run root-cause analysis first.")
        )

        XCTAssertEqual(payload, "localhost:3000/api/v1?draft=1")
    }
}
