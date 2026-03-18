import XCTest
@testable import Prompt_Cue

final class AppEnvironmentTests: XCTestCase {
    func testStartupFlagsReadEnabledValues() {
        let environment = AppEnvironment(
            values: [
                "PROMPTCUE_OPEN_DESIGN_SYSTEM": "1",
                "PROMPTCUE_OPEN_STACK_ON_START": "1",
                "PROMPTCUE_OPEN_SETTINGS_ON_START": "1",
                "PROMPTCUE_OPEN_SETTINGS_TAB": "connectors",
                "PROMPTCUE_OPEN_CAPTURE_ON_START": "1",
            ]
        )

        XCTAssertTrue(environment.shouldOpenDesignSystemOnStart)
        XCTAssertTrue(environment.shouldOpenStackOnStart)
        XCTAssertTrue(environment.shouldOpenSettingsOnStart)
        XCTAssertEqual(environment.startupSettingsTab, .connectors)
        XCTAssertTrue(environment.shouldOpenCaptureOnStart)
    }

    func testInvalidStartupSettingsTabIsIgnored() {
        let environment = AppEnvironment(
            values: [
                "PROMPTCUE_OPEN_SETTINGS_TAB": "unknown",
            ]
        )

        XCTAssertNil(environment.startupSettingsTab)
    }

    func testStartupSettingsTabImplicitlyOpensSettings() {
        let environment = AppEnvironment(
            values: [
                "PROMPTCUE_OPEN_SETTINGS_TAB": "connectors",
            ]
        )

        XCTAssertTrue(environment.shouldOpenSettingsOnStart)
        XCTAssertEqual(environment.startupSettingsTab, .connectors)
    }

    func testStartupSettingsTabReadsCommandLineArgument() {
        let environment = AppEnvironment(
            values: [:],
            arguments: ["Prompt Cue", "--open-settings-tab", "connectors"]
        )

        XCTAssertTrue(environment.shouldOpenSettingsOnStart)
        XCTAssertEqual(environment.startupSettingsTab, .connectors)
    }

    func testDraftSeedValuesTrimWhitespaceAndTreatEmptyAsMissing() {
        let environment = AppEnvironment(
            values: [
                "PROMPTCUE_QA_DRAFT_TEXT": "  seeded text  ",
                "PROMPTCUE_QA_DRAFT_TEXT_FILE": "   ",
            ]
        )

        XCTAssertEqual(environment.qaDraftText, "seeded text")
        XCTAssertNil(environment.qaDraftTextFilePath)
    }

    func testExperimentalMCPHTTPFlagsReadValues() {
        let environment = AppEnvironment(
            values: [
                "PROMPTCUE_EXPERIMENTAL_MCP_HTTP_ON_START": "1",
                "PROMPTCUE_EXPERIMENTAL_MCP_HTTP_PORT": "9123",
                "PROMPTCUE_EXPERIMENTAL_MCP_HTTP_API_KEY": "  secret-key  ",
            ]
        )

        XCTAssertTrue(environment.shouldLaunchExperimentalMCPHTTPOnStart)
        XCTAssertEqual(environment.experimentalMCPHTTPPort, 9123)
        XCTAssertEqual(environment.experimentalMCPHTTPAPIKey, "secret-key")
    }

    func testExperimentalMCPHTTPPortFallsBackToDefault() {
        let environment = AppEnvironment(
            values: [
                "PROMPTCUE_EXPERIMENTAL_MCP_HTTP_PORT": "not-a-number",
            ]
        )

        XCTAssertEqual(environment.experimentalMCPHTTPPort, 8321)
    }
}
