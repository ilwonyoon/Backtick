import Foundation
import XCTest
import PromptCueCore
@testable import Prompt_Cue

@MainActor
final class CardStorePerformanceTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private let fixtureCardCount = 600
    private let benchmarkRunEnabled: Bool = {
#if PROMPTCUE_RUN_PERF_BENCHMARKS
        true
#else
        ProcessInfo.processInfo.environment["PROMPTCUE_RUN_PERF_BENCHMARKS"] == "1"
#endif
    }()
    private let benchmarkIterations = {
        if let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_CARD_STORE_BENCHMARK_ITERATIONS"],
           let parsedValue = Int(rawValue),
           parsedValue > 0 {
            return parsedValue
        }

        return 24
    }()

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

    func testSingleCardMutationIncrementalWriteBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run CardStore benchmarks."
        )

        let fixtureCards = makeFixtureCards(count: fixtureCardCount)
        let targetCard = fixtureCards[fixtureCards.count / 2]
        let mutatedCard = targetCard.markCopied(at: Date(timeIntervalSinceReferenceDate: 9_999))
        let replacedCards = fixtureCards.map { card in
            card.id == mutatedCard.id ? mutatedCard : card
        }

        let fullReplace = try benchmark(
            label: "full-replace-mutation",
            seedCards: fixtureCards
        ) { store, _ in
            try store.replaceAll(replacedCards)
        }

        let incremental = try benchmark(
            label: "incremental-upsert-mutation",
            seedCards: fixtureCards
        ) { store, _ in
            try store.upsert([mutatedCard])
        }

        let speedup = fullReplace.totalMilliseconds / max(incremental.totalMilliseconds, 0.001)
        print(
            String(
                format: "CardStore benchmark [mutation]: replaceAll=%.2fms incrementalUpsert=%.2fms speedup=%.2fx iterations=%d",
                fullReplace.totalMilliseconds,
                incremental.totalMilliseconds,
                speedup,
                benchmarkIterations
            )
        )

        XCTAssertGreaterThan(fullReplace.totalMilliseconds, incremental.totalMilliseconds)
    }

    func testSingleCardDeleteIncrementalWriteBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run CardStore benchmarks."
        )

        let fixtureCards = makeFixtureCards(count: fixtureCardCount)
        let targetCard = fixtureCards[fixtureCards.count / 2]
        let remainingCards = fixtureCards.filter { $0.id != targetCard.id }

        let fullReplace = try benchmark(
            label: "full-replace-delete",
            seedCards: fixtureCards
        ) { store, _ in
            try store.replaceAll(remainingCards)
        }

        let incremental = try benchmark(
            label: "incremental-delete",
            seedCards: fixtureCards
        ) { store, _ in
            try store.delete(ids: [targetCard.id])
        }

        let speedup = fullReplace.totalMilliseconds / max(incremental.totalMilliseconds, 0.001)
        print(
            String(
                format: "CardStore benchmark [delete]: replaceAll=%.2fms incrementalDelete=%.2fms speedup=%.2fx iterations=%d",
                fullReplace.totalMilliseconds,
                incremental.totalMilliseconds,
                speedup,
                benchmarkIterations
            )
        )

        XCTAssertGreaterThan(fullReplace.totalMilliseconds, incremental.totalMilliseconds)
    }

    private func benchmark(
        label: String,
        seedCards: [CaptureCard],
        operation: (CardStore, Int) throws -> Void
    ) throws -> BenchmarkResult {
        var totalMilliseconds = 0.0

        for iteration in 0..<benchmarkIterations {
            let databaseURL = tempDirectoryURL.appendingPathComponent("\(label)-\(iteration).sqlite")
            let store = CardStore(databaseURL: databaseURL)
            try store.replaceAll(seedCards)

            let startedAt = CFAbsoluteTimeGetCurrent()
            try operation(store, iteration)
            totalMilliseconds += (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
        }

        let averageMilliseconds = totalMilliseconds / Double(benchmarkIterations)
        print(
            String(
                format: "CardStore benchmark [%@]: total=%.2fms avg=%.2fms iterations=%d",
                label,
                totalMilliseconds,
                averageMilliseconds,
                benchmarkIterations
            )
        )

        return BenchmarkResult(
            totalMilliseconds: totalMilliseconds,
            averageMilliseconds: averageMilliseconds,
            iterationCount: benchmarkIterations
        )
    }

    private func makeFixtureCards(count: Int) -> [CaptureCard] {
        (0..<count).map { index in
            CaptureCard(
                id: UUID(),
                text: "Fixture card \(index) keeps storage paths representative under stack-sized load.",
                createdAt: Date(timeIntervalSinceReferenceDate: Double(index)),
                screenshotPath: index.isMultiple(of: 6) ? "/tmp/fixture-\(index).png" : nil,
                lastCopiedAt: index.isMultiple(of: 5) ? Date(timeIntervalSinceReferenceDate: Double(index + 1_000)) : nil,
                sortOrder: Double(count - index)
            )
        }
    }
}

private struct BenchmarkResult {
    let totalMilliseconds: Double
    let averageMilliseconds: Double
    let iterationCount: Int
}
