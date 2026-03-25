import Foundation
import XCTest
import PromptCueCore
@testable import Prompt_Cue

@MainActor
final class AppModelCloudSyncLifecycleTests: XCTestCase {
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

    func testStartDoesNotCreateCloudSyncEngineUntilSyncEnabled() async {
        let engine = RecordingCloudSyncEngine()
        var factoryCallCount = 0
        let model = makeModel(cloudSyncEngine: nil) {
            factoryCallCount += 1
            return engine
        }
        defer { model.stop() }

        model.start(startupMode: .deferredMaintenance)
        XCTAssertEqual(factoryCallCount, 0)

        model.setSyncEnabled(true)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertEqual(engine.setupCallCount, 1)
        XCTAssertEqual(engine.fetchRemoteChangesCallCount, 1)
    }

    func testDisablingSyncStopsExistingCloudSyncEngine() {
        let engine = RecordingCloudSyncEngine()
        let model = makeModel(cloudSyncEngine: engine)
        defer { model.stop() }

        model.start(startupMode: .deferredMaintenance)
        model.setSyncEnabled(false)

        XCTAssertEqual(engine.stopCallCount, 1)
    }

    func testEnablingSyncPushesExistingCardsToRemote() async throws {
        let cardStore = CardStore(databaseURL: tempDirectoryURL.appendingPathComponent("PromptCue.sqlite"))
        let card = CaptureCard(text: "Pre-existing card", createdAt: Date())
        try cardStore.save([card])

        let engine = RecordingCloudSyncEngine()
        var factoryCallCount = 0
        let model = AppModel(
            cardStore: cardStore,
            attachmentStore: AttachmentStore(
                baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments", isDirectory: true)
            ),
            recentScreenshotCoordinator: LifecycleTestRecentScreenshotCoordinator(),
            cloudSyncEngine: nil,
            cloudSyncEngineFactory: {
                factoryCallCount += 1
                return engine
            },
            requiresCloudEntitlements: false
        )
        defer { model.stop() }

        model.start(startupMode: .deferredMaintenance)
        model.setSyncEnabled(true)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertEqual(engine.pushAllLocalCardsCards.count, 1)
        XCTAssertEqual(engine.pushAllLocalCardsCards.first?.count, 1)
        XCTAssertEqual(engine.pushAllLocalCardsCards.first?.first?.text, "Pre-existing card")
    }

    func testStopStopsExistingCloudSyncEngine() {
        let engine = RecordingCloudSyncEngine()
        let model = makeModel(cloudSyncEngine: engine)

        model.start(startupMode: .deferredMaintenance)
        model.stop()

        XCTAssertEqual(engine.stopCallCount, 1)
    }

    private func makeModel(
        cloudSyncEngine: (any CloudSyncControlling)?,
        cloudSyncEngineFactory: @escaping @MainActor () -> any CloudSyncControlling = { RecordingCloudSyncEngine() }
    ) -> AppModel {
        AppModel(
            cardStore: CardStore(databaseURL: tempDirectoryURL.appendingPathComponent("PromptCue.sqlite")),
            attachmentStore: AttachmentStore(
                baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments", isDirectory: true)
            ),
            recentScreenshotCoordinator: LifecycleTestRecentScreenshotCoordinator(),
            cloudSyncEngine: cloudSyncEngine,
            cloudSyncEngineFactory: cloudSyncEngineFactory,
            requiresCloudEntitlements: false
        )
    }
}

@MainActor
private final class RecordingCloudSyncEngine: CloudSyncControlling {
    weak var delegate: CloudSyncDelegate?

    private(set) var setupCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var fetchRemoteChangesCallCount = 0
    private(set) var handleRemoteNotificationCallCount = 0
    private(set) var pushLocalChangeCallCount = 0
    private(set) var pushDeletionCallCount = 0
    private(set) var pushBatchCallCount = 0
    private(set) var pushAllLocalCardsCards: [[CaptureCard]] = []
    private(set) var pushAllLocalDocumentsDocuments: [[ProjectDocument]] = []

    func setup() async {
        setupCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func fetchRemoteChanges() {
        fetchRemoteChangesCallCount += 1
    }

    func handleRemoteNotification() {
        handleRemoteNotificationCallCount += 1
    }

    func pushLocalChange(card: CaptureCard) {
        pushLocalChangeCallCount += 1
    }

    func pushDeletion(id: UUID) {
        pushDeletionCallCount += 1
    }

    func pushBatch(cards: [CaptureCard], deletions: [UUID]) {
        pushBatchCallCount += 1
    }

    func pushAllLocalCards(cards: [CaptureCard]) {
        pushAllLocalCardsCards.append(cards)
    }

    func pushLocalChange(document: ProjectDocument) {}
    func pushDocumentDeletion(id: UUID) {}
    func pushAllLocalDocuments(documents: [ProjectDocument]) {
        pushAllLocalDocumentsDocuments.append(documents)
    }
}

@MainActor
private final class LifecycleTestRecentScreenshotCoordinator: RecentScreenshotCoordinating {
    var state: RecentScreenshotState = .idle
    var onStateChange: ((RecentScreenshotState) -> Void)?

    func start() {}
    func stop() {}
    func prepareForCaptureSession() {}
    func endCaptureSession() {}
    func refreshNow() {}
    func resolveCurrentCaptureAttachment(timeout: TimeInterval) async -> URL? { nil }
    func consumeCurrent() {}
    func dismissCurrent() {}
    func suspendExpiration() {}
    func resumeExpiration() {}
}
