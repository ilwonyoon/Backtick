import Foundation
import XCTest
@testable import Prompt_Cue

@MainActor
final class LaunchAtLoginSettingsTests: XCTestCase {
    func testRefreshLoadsEnabledStatus() {
        let controller = StubLaunchAtLoginController(status: .enabled)
        let model = LaunchAtLoginSettingsModel(controller: controller)

        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(model.status, .enabled)
    }

    func testRequiresApprovalKeepsToggleOnAndShowsGuidance() {
        let controller = StubLaunchAtLoginController(status: .requiresApproval)
        let model = LaunchAtLoginSettingsModel(controller: controller)

        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(model.status, .requiresApproval)
        XCTAssertTrue(model.detailText.contains("Login Items"))
    }

    func testUpdateEnabledPersistsThroughControllerAndRefreshesStatus() {
        let controller = StubLaunchAtLoginController(status: .disabled)
        let model = LaunchAtLoginSettingsModel(controller: controller)

        model.updateEnabled(true)

        XCTAssertEqual(controller.setEnabledCalls, [true])
        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertNil(model.lastError)
    }

    func testUpdateEnabledRestoresPreviousStateWhenControllerThrows() {
        let controller = StubLaunchAtLoginController(
            status: .disabled,
            setEnabledError: TestError.failed
        )
        let model = LaunchAtLoginSettingsModel(controller: controller)

        model.updateEnabled(true)

        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(model.status, .disabled)
        XCTAssertEqual(model.lastError, TestError.failed.localizedDescription)
    }
}

@MainActor
private final class StubLaunchAtLoginController: LaunchAtLoginControlling {
    private(set) var currentStatus: LaunchAtLoginStatus
    private let setEnabledError: Error?
    private(set) var setEnabledCalls: [Bool] = []

    init(
        status: LaunchAtLoginStatus,
        setEnabledError: Error? = nil
    ) {
        currentStatus = status
        self.setEnabledError = setEnabledError
    }

    func status() -> LaunchAtLoginStatus {
        currentStatus
    }

    func setEnabled(_ isEnabled: Bool) throws {
        setEnabledCalls.append(isEnabled)

        if let setEnabledError {
            throw setEnabledError
        }

        currentStatus = isEnabled ? .enabled : .disabled
    }
}

private enum TestError: LocalizedError {
    case failed

    var errorDescription: String? {
        "Registration failed."
    }
}
