import XCTest
@testable import Prompt_Cue

final class AppEnvironmentTests: XCTestCase {
    func testStartupFlagsReadEnabledValues() {
        let environment = AppEnvironment(
            values: [
                "PROMPTCUE_OPEN_DESIGN_SYSTEM": "1",
                "PROMPTCUE_OPEN_STACK_ON_START": "1",
                "PROMPTCUE_OPEN_CAPTURE_ON_START": "1",
            ]
        )

        XCTAssertTrue(environment.shouldOpenDesignSystemOnStart)
        XCTAssertTrue(environment.shouldOpenStackOnStart)
        XCTAssertTrue(environment.shouldOpenCaptureOnStart)
    }

    func testExecutionMapFlagsUseMCPEnvironmentKeys() {
        let environment = AppEnvironment(
            values: [
                "PROMPTCUE_ENABLE_MCP": "1",
                "PROMPTCUE_OPEN_MCP_ON_START": "1",
            ]
        )

        XCTAssertTrue(environment.isExecutionMapEnabled)
        XCTAssertTrue(environment.shouldOpenExecutionMapOnStart)
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
}
