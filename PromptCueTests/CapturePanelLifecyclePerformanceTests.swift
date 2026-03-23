import AppKit
import Foundation
import XCTest
@testable import Prompt_Cue

@MainActor
final class CapturePanelLifecyclePerformanceTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private let benchmarkRunEnabled: Bool = {
#if PROMPTCUE_RUN_PERF_BENCHMARKS
        true
#else
        ProcessInfo.processInfo.environment["PROMPTCUE_RUN_PERF_BENCHMARKS"] == "1"
#endif
    }()
    private let showFocusIterations = {
        if let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_CAPTURE_SHOW_FOCUS_BENCHMARK_ITERATIONS"],
           let parsedValue = Int(rawValue),
           parsedValue > 0 {
            return parsedValue
        }

        return 30
    }()
    private let submitCloseIterations = {
        if let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_CAPTURE_SUBMIT_CLOSE_BENCHMARK_ITERATIONS"],
           let parsedValue = Int(rawValue),
           parsedValue > 0 {
            return parsedValue
        }

        return 30
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

    func testCaptureShowFocusesEditor() throws {
        let fixture = try makeFixture(databaseLabel: "show-focus-smoke")
        defer { fixture.close() }

        fixture.controller.show()

        XCTAssertTrue(
            waitUntil(seconds: 0.5) {
                fixture.controller.debugRuntimeViewController?.debugIsEditorFirstResponder == true
            },
            "Capture editor should become first responder after the panel opens."
        )
    }

    func testCaptureSubmitClosesPanelAndPersistsCard() throws {
        let fixture = try makeFixture(databaseLabel: "submit-close-smoke")
        defer { fixture.close() }

        fixture.controller.show()
        XCTAssertTrue(
            waitUntil(seconds: 0.5) {
                fixture.controller.debugRuntimeViewController?.debugIsEditorFirstResponder == true
            },
            "Capture editor should become first responder before submit."
        )

        let runtimeController = try XCTUnwrap(fixture.controller.debugRuntimeViewController)
        let draftText = "Capture lifecycle smoke"
        runtimeController.debugApplyEditorText(draftText, selectedLocation: draftText.utf16.count)
        runtimeController.debugTriggerSubmit()

        XCTAssertTrue(
            waitUntil(seconds: 1.0) {
                !fixture.controller.debugIsVisible && !fixture.model.isSubmittingCapture
            },
            "Capture panel should close after a successful submit."
        )
        XCTAssertTrue(
            waitUntil(seconds: 0.5) {
                fixture.model.draftText.isEmpty
            },
            "Successful submit should still clear the draft shortly after the panel closes."
        )
        XCTAssertEqual(fixture.model.cards.count, 1)
        XCTAssertEqual(fixture.model.cards.first?.text, draftText)
    }

    func testCaptureShowToFocusedEditorBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run capture lifecycle benchmarks."
        )

        let summary = try benchmark(
            label: "show-focus",
            iterations: showFocusIterations
        ) { iteration in
            let fixture = try makeFixture(databaseLabel: "show-focus-\(iteration)")
            defer { fixture.close() }

            return try measure {
                fixture.controller.show()
                guard waitUntil(
                    seconds: 0.5,
                    condition: {
                        fixture.controller.debugRuntimeViewController?.debugIsEditorFirstResponder == true
                    }
                ) else {
                    throw BenchmarkError.timeout("Capture editor did not become first responder.")
                }
            }
        }

        printSummary(summary, prefix: "Capture lifecycle benchmark")
        XCTAssertGreaterThan(summary.averageMilliseconds, 0)
    }

    func testCaptureSubmitToPanelCloseBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run capture lifecycle benchmarks."
        )

        let summary = try benchmark(
            label: "submit-close",
            iterations: submitCloseIterations
        ) { iteration in
            let fixture = try makeFixture(databaseLabel: "submit-close-\(iteration)")
            defer { fixture.close() }

            fixture.controller.show()
            guard waitUntil(
                seconds: 0.5,
                condition: {
                    fixture.controller.debugRuntimeViewController?.debugIsEditorFirstResponder == true
                }
            ) else {
                throw BenchmarkError.timeout("Capture editor did not become first responder before submit.")
            }

            let runtimeController = try XCTUnwrap(fixture.controller.debugRuntimeViewController)
            let draftText = "hello world \(iteration)"
            runtimeController.debugApplyEditorText(
                draftText,
                selectedLocation: draftText.utf16.count
            )

            let sample = try measure {
                runtimeController.debugTriggerSubmit()
                guard waitUntil(
                    seconds: 1.0,
                    condition: {
                        !fixture.controller.debugIsVisible && !fixture.model.isSubmittingCapture
                    }
                ) else {
                    throw BenchmarkError.timeout("Capture panel did not close after submit.")
                }
            }

            XCTAssertEqual(fixture.model.cards.count, 1)
            return sample
        }

        printSummary(summary, prefix: "Capture lifecycle benchmark")
        XCTAssertGreaterThan(summary.averageMilliseconds, 0)
    }

    private func benchmark(
        label: String,
        iterations: Int,
        scenario: (Int) throws -> Sample
    ) throws -> BenchmarkSummary {
        var samples: [Sample] = []
        samples.reserveCapacity(iterations)

        for iteration in 0..<iterations {
            samples.append(
                try runInAutoreleasePool {
                    try scenario(iteration)
                }
            )
        }

        return BenchmarkSummary(label: label, samples: samples)
    }

    private func measure(
        operation: () throws -> Void
    ) throws -> Sample {
        let startedAt = CFAbsoluteTimeGetCurrent()
        try operation()
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
        return Sample(elapsedMilliseconds: elapsedMilliseconds)
    }

    private func waitUntil(
        seconds: TimeInterval,
        pollInterval: TimeInterval = 0.005,
        condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)

        while Date() < deadline {
            if condition() {
                return true
            }

            RunLoop.main.run(until: Date().addingTimeInterval(pollInterval))
        }

        return condition()
    }

    private func makeFixture(databaseLabel: String) throws -> ControllerFixture {
        let store = CardStore(databaseURL: tempDirectoryURL.appendingPathComponent("\(databaseLabel).sqlite"))
        let model = AppModel(
            cardStore: store,
            attachmentStore: AttachmentStore(
                baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments-\(databaseLabel)", isDirectory: true)
            ),
            recentScreenshotCoordinator: BenchmarkRecentScreenshotCoordinator()
        )
        model.start()

        let controller = CapturePanelController(model: model)
        return ControllerFixture(model: model, controller: controller)
    }

    private func printSummary(_ summary: BenchmarkSummary, prefix: String) {
        print(
            String(
                format: "%@ [%@]: avg=%.2fms p95=%.2fms max=%.2fms iterations=%d",
                prefix,
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
}

private struct ControllerFixture {
    let model: AppModel
    let controller: CapturePanelController

    @MainActor
    func close() {
        controller.close(persistDraft: false)
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

private enum BenchmarkError: Error {
    case timeout(String)
}
