import AppKit
import Foundation
import PromptCueCore
import XCTest
@testable import Prompt_Cue

@MainActor
final class CaptureTypingPerformanceTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private let benchmarkRunEnabled: Bool = {
#if PROMPTCUE_RUN_PERF_BENCHMARKS
        true
#else
        ProcessInfo.processInfo.environment["PROMPTCUE_RUN_PERF_BENCHMARKS"] == "1"
#endif
    }()
    private let benchmarkIterations = {
        if let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_CAPTURE_TYPING_BENCHMARK_ITERATIONS"],
           let parsedValue = Int(rawValue),
           parsedValue > 0 {
            return parsedValue
        }

        return 40
    }()

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testPlainTextTypingBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run capture typing benchmarks."
        )

        let result = try benchmark(label: "plain-text") { iteration in
            let fixture = try makePreparedController(
                databaseLabel: "plain-\(iteration)",
                cards: []
            )
            defer { fixture.close() }

            fixture.controller.debugApplyEditorText("alpha beta ", selectedLocation: 11)
            return measure(finalText: {
                fixture.controller.debugEditorText
            }) {
                typeText("hello world", into: fixture.controller)
            }
        }

        printSummary(result)
        XCTAssertGreaterThan(result.averageMilliseconds, 0)
        XCTAssertEqual(result.lastObservedText, "alpha beta hello world")
    }

    func testInlineTagTypingBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run capture typing benchmarks."
        )

        let result = try benchmark(label: "inline-tag") { iteration in
            let fixture = try makePreparedController(
                databaseLabel: "inline-\(iteration)",
                cards: [
                    makeTaggedCard(text: "First", tags: ["tag_test"]),
                    makeTaggedCard(text: "Second", tags: ["tag_helper"]),
                    makeTaggedCard(text: "Third", tags: ["backtick"]),
                ]
            )
            defer { fixture.close() }

            fixture.controller.debugApplyEditorText("alpha beta gamma", selectedLocation: 11)
            return measure(finalText: {
                fixture.controller.debugEditorText
            }) {
                typeText("#tag_test ", into: fixture.controller)
            }
        }

        printSummary(result)
        XCTAssertGreaterThan(result.averageMilliseconds, 0)
        XCTAssertEqual(result.lastObservedText, "alpha beta #tag_test gamma")
    }

    func testKoreanIMECompositionBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run capture typing benchmarks."
        )

        let result = try benchmark(label: "ime-compose-commit") { iteration in
            let fixture = try makePreparedController(
                databaseLabel: "ime-\(iteration)",
                cards: []
            )
            defer { fixture.close() }

            fixture.controller.debugApplyEditorText("", selectedLocation: 0)
            return measure(finalText: {
                fixture.controller.debugEditorText
            }) {
                fixture.controller.debugSetMarkedText("ㅎ", selectedLocation: 1)
                fixture.controller.debugSetMarkedText("하", selectedLocation: 1)
                fixture.controller.debugSetMarkedText("한", selectedLocation: 1)
                fixture.controller.debugApplyEditorText("한", selectedLocation: 1)
            }
        }

        printSummary(result)
        XCTAssertGreaterThan(result.averageMilliseconds, 0)
        XCTAssertEqual(result.lastObservedText, "한")
    }

    private func benchmark(
        label: String,
        scenario: (Int) throws -> Sample
    ) throws -> BenchmarkSummary {
        var samples: [Sample] = []
        samples.reserveCapacity(benchmarkIterations)

        for iteration in 0..<benchmarkIterations {
            samples.append(try runInAutoreleasePool {
                try scenario(iteration)
            })
        }

        return BenchmarkSummary(label: label, samples: samples)
    }

    private func measure(
        finalText: () -> String,
        operation: () -> Void
    ) -> Sample {
        let startedAt = CFAbsoluteTimeGetCurrent()
        operation()
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
        return Sample(
            elapsedMilliseconds: elapsedMilliseconds,
            finalText: finalText()
        )
    }

    private func typeText(_ text: String, into controller: CapturePanelRuntimeViewController) {
        for scalar in text {
            controller.debugInsertText(String(scalar))
        }
    }

    private func makePreparedController(
        databaseLabel: String,
        cards: [CaptureCard]
    ) throws -> ControllerFixture {
        let store = CardStore(databaseURL: tempDirectoryURL.appendingPathComponent("\(databaseLabel).sqlite"))
        if !cards.isEmpty {
            try store.replaceAll(cards)
        }

        let model = AppModel(
            cardStore: store,
            attachmentStore: AttachmentStore(
                baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments-\(databaseLabel)", isDirectory: true)
            ),
            recentScreenshotCoordinator: BenchmarkRecentScreenshotCoordinator()
        )
        model.start()

        let controller = CapturePanelRuntimeViewController(model: model)
        controller.loadViewIfNeeded()
        controller.view.frame = NSRect(x: 0, y: 0, width: AppUIConstants.capturePanelWidth, height: 320)
        controller.view.layoutSubtreeIfNeeded()
        controller.prepareForPresentation()

        let window = TestCapturePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: AppUIConstants.capturePanelWidth,
                height: controller.currentPreferredPanelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        controller.debugMakeEditorFirstResponder()
        window.layoutIfNeeded()
        window.layoutIfNeeded()

        return ControllerFixture(
            model: model,
            controller: controller,
            window: window
        )
    }

    private func makeTaggedCard(text: String, tags: [String]) -> CaptureCard {
        CaptureCard(
            id: UUID(),
            text: text,
            tags: tags.compactMap { CaptureTag(rawValue: $0) },
            createdAt: Date(),
            sortOrder: Date().timeIntervalSinceReferenceDate
        )
    }

    private func printSummary(_ summary: BenchmarkSummary) {
        print(
            String(
                format: "Capture typing benchmark [%@]: avg=%.2fms p95=%.2fms max=%.2fms iterations=%d",
                summary.label,
                summary.averageMilliseconds,
                summary.p95Milliseconds,
                summary.maxMilliseconds,
                summary.samples.count
            )
        )
    }

    private func runInAutoreleasePool<T>(
        _ operation: () throws -> T
    ) throws -> T {
        var result: Result<T, Error>!

        autoreleasepool {
            result = Result {
                try operation()
            }
        }

        return try result.get()
    }
}

private struct Sample {
    let elapsedMilliseconds: Double
    let finalText: String?
}

private struct BenchmarkSummary {
    let label: String
    let samples: [Sample]

    var averageMilliseconds: Double {
        samples.map(\.elapsedMilliseconds).reduce(0, +) / Double(max(samples.count, 1))
    }

    var p95Milliseconds: Double {
        guard !samples.isEmpty else {
            return 0
        }

        let sortedSamples = samples.map(\.elapsedMilliseconds).sorted()
        let index = max(0, Int(ceil(Double(sortedSamples.count) * 0.95)) - 1)
        return sortedSamples[index]
    }

    var maxMilliseconds: Double {
        samples.map(\.elapsedMilliseconds).max() ?? 0
    }

    var lastObservedText: String? {
        samples.last?.finalText
    }
}

private struct ControllerFixture {
    let model: AppModel
    let controller: CapturePanelRuntimeViewController
    let window: TestCapturePanel

    @MainActor
    func close() {
        controller.discardPendingDraftSync()
        window.contentViewController = nil
        window.orderOut(nil)
        window.close()
        model.stop()
    }
}

@MainActor
private final class BenchmarkRecentScreenshotCoordinator: RecentScreenshotCoordinating {
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

private final class TestCapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
