import AppKit
import Foundation
import PromptCueCore
import XCTest
@testable import Prompt_Cue

@MainActor
final class StackPanelVisualPerformanceTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var originalRetentionState: CardRetentionState!

    private let fixtureCardCount = 28
    private let benchmarkRunEnabled: Bool = {
#if PROMPTCUE_RUN_PERF_BENCHMARKS
        true
#else
        ProcessInfo.processInfo.environment["PROMPTCUE_RUN_PERF_BENCHMARKS"] == "1"
#endif
    }()
    private let benchmarkIterations = {
        if let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_STACK_VISUAL_BENCHMARK_ITERATIONS"],
           let parsedValue = Int(rawValue),
           parsedValue > 0 {
            return parsedValue
        }

        return 18
    }()

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalRetentionState = CardRetentionPreferences.load()
        CardRetentionPreferences.save(CardRetentionState(isAutoExpireEnabled: false))
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let originalRetentionState {
            CardRetentionPreferences.save(originalRetentionState)
        }
        originalRetentionState = nil
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testStackVisualRenderBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run stack visual benchmarks."
        )

        let result = try benchmark()
        print(
            String(
                format: "Stack visual benchmark [render-prep]: total=%.2fms avg=%.2fms iterations=%d cards=%d schemes=%d",
                result.totalMilliseconds,
                result.averageMilliseconds,
                result.iterationCount,
                fixtureCardCount,
                result.schemeCount
            )
        )

        XCTAssertGreaterThan(result.totalMilliseconds, 0)
    }

    private func benchmark() throws -> StackVisualBenchmarkResult {
        let light = try benchmark(
            label: "light",
            appearanceName: .aqua
        )
        let dark = try benchmark(
            label: "dark",
            appearanceName: .darkAqua
        )

        let totalMilliseconds = light.totalMilliseconds + dark.totalMilliseconds
        let totalRuns = light.iterationCount + dark.iterationCount
        let averageMilliseconds = totalMilliseconds / Double(max(totalRuns, 1))

        return StackVisualBenchmarkResult(
            totalMilliseconds: totalMilliseconds,
            averageMilliseconds: averageMilliseconds,
            iterationCount: totalRuns,
            schemeCount: 2
        )
    }

    private func benchmark(
        label: String,
        appearanceName: NSAppearance.Name
    ) throws -> StackVisualSchemeBenchmarkResult {
        guard let appearance = NSAppearance(named: appearanceName) else {
            XCTFail("Could not create appearance \(appearanceName.rawValue)")
            return StackVisualSchemeBenchmarkResult(totalMilliseconds: 0, averageMilliseconds: 0, iterationCount: 0)
        }

        var totalMilliseconds = 0.0

        for _ in 0..<benchmarkIterations {
            let model = try makeModel(label: label)
            let controller = StackPanelController(model: model)
            let previousAppearance = NSApp.appearance
            NSApp.appearance = appearance

            let startedAt = CFAbsoluteTimeGetCurrent()
            controller.prepareForFirstPresentation()
            controller.refreshForInheritedAppearanceChange()
            totalMilliseconds += (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000

            NSApp.appearance = previousAppearance
        }

        let averageMilliseconds = totalMilliseconds / Double(max(benchmarkIterations, 1))
        print(
            String(
                format: "Stack visual benchmark [%@]: total=%.2fms avg=%.2fms iterations=%d cards=%d",
                label,
                totalMilliseconds,
                averageMilliseconds,
                benchmarkIterations,
                fixtureCardCount
            )
        )

        return StackVisualSchemeBenchmarkResult(
            totalMilliseconds: totalMilliseconds,
            averageMilliseconds: averageMilliseconds,
            iterationCount: benchmarkIterations
        )
    }

    private func makeModel(label: String) throws -> AppModel {
        let databaseURL = tempDirectoryURL.appendingPathComponent("stack-visual-\(label).sqlite")
        let cardStore = CardStore(databaseURL: databaseURL)
        let model = AppModel(
            cardStore: cardStore,
            attachmentStore: BenchmarkAttachmentStore(
                baseDirectoryURL: tempDirectoryURL.appendingPathComponent("Attachments", isDirectory: true)
            ),
            recentScreenshotCoordinator: BenchmarkRecentScreenshotCoordinator()
        )
        model.cards = makeFixtureCards()
        return model
    }

    private func makeFixtureCards() -> [CaptureCard] {
        let baseDate = Date(timeIntervalSinceReferenceDate: 10_000)
        let activeCount = 20
        let copiedCount = fixtureCardCount - activeCount

        let activeCards = (0..<activeCount).map { index in
            CaptureCard(
                id: UUID(),
                text: fixtureText(index: index, isCopied: false),
                tags: fixtureTags(for: index),
                createdAt: baseDate.addingTimeInterval(Double(index)),
                lastCopiedAt: nil,
                sortOrder: Double(fixtureCardCount - index)
            )
        }

        let copiedCards = (0..<copiedCount).map { index in
            let fixtureIndex = activeCount + index
            return CaptureCard(
                id: UUID(),
                text: fixtureText(index: fixtureIndex, isCopied: true),
                tags: fixtureTags(for: fixtureIndex),
                createdAt: baseDate.addingTimeInterval(Double(fixtureIndex)),
                lastCopiedAt: baseDate.addingTimeInterval(Double(1_000 + fixtureIndex)),
                sortOrder: Double(copiedCount - index)
            )
        }

        return activeCards + copiedCards
    }

    private func fixtureText(index: Int, isCopied: Bool) -> String {
        let header = isCopied
            ? "Backtick offstage fixture \(index)"
            : "Backtick on-stage fixture \(index)"
        let body = Array(
            repeating: "Stack render benchmarking should stress long-card wrapping, copy affordances, and collapsed copied summaries without relying on screenshot payloads.",
            count: 4 + (index % 3)
        )
        .joined(separator: " ")

        return "\(header). \(body)"
    }

    private func fixtureTags(for index: Int) -> [CaptureTag] {
        if index.isMultiple(of: 3) {
            return CaptureTag.canonicalize(rawValues: ["swift", "stack_perf"])
        }

        if index.isMultiple(of: 5) {
            return CaptureTag.canonicalize(rawValues: ["ui"])
        }

        return []
    }
}

private struct StackVisualBenchmarkResult {
    let totalMilliseconds: Double
    let averageMilliseconds: Double
    let iterationCount: Int
    let schemeCount: Int
}

private struct StackVisualSchemeBenchmarkResult {
    let totalMilliseconds: Double
    let averageMilliseconds: Double
    let iterationCount: Int
}

private struct BenchmarkAttachmentStore: AttachmentStoring {
    let baseDirectoryURL: URL

    func importScreenshot(from sourceURL: URL, ownerID: UUID) throws -> URL {
        sourceURL
    }

    func removeManagedFile(at fileURL: URL) throws {}

    func pruneUnreferencedManagedFiles(referencedFileURLs: Set<URL>) throws {}

    func isManagedFile(_ fileURL: URL) -> Bool {
        true
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
    func suspendExpiration() {}
    func resumeExpiration() {}
    func consumeCurrent() {}
    func dismissCurrent() {}
}
