import AppKit
import XCTest
@testable import Prompt_Cue

@MainActor
final class CapturePreviewImagePerformanceTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private let benchmarkRunEnabled: Bool = {
#if PROMPTCUE_RUN_PERF_BENCHMARKS
        true
#else
        ProcessInfo.processInfo.environment["PROMPTCUE_RUN_PERF_BENCHMARKS"] == "1"
#endif
    }()
    private let benchmarkIterations = {
        if let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_CAPTURE_PREVIEW_BENCHMARK_ITERATIONS"],
           let parsedValue = Int(rawValue),
           parsedValue > 0 {
            return parsedValue
        }

        return 120
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

    func testRepeatedPreviewLoadWarmCacheBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run capture preview benchmarks."
        )

        let fixtureURL = tempDirectoryURL.appendingPathComponent("capture-preview-fixture.png")
        try makeFixtureImage(at: fixtureURL, size: NSSize(width: 2048, height: 1536))

        let baseline = benchmark(label: "direct-decode-load") {
            let image = CapturePreviewImageCache.loadUncachedImage(from: fixtureURL)
            XCTAssertNotNil(image)
            _ = image?.tiffRepresentation?.count
        }

        let cache = CapturePreviewImageCache()
        let sessionID = UUID()
        let prewarmedImage = cache.cachedImage(
            sessionID: sessionID,
            cacheURL: fixtureURL,
            loader: CapturePreviewImageCache.loadUncachedImage(from:)
        )
        XCTAssertNotNil(prewarmedImage)

        let warmCache = benchmark(label: "warm-cache-load") {
            let image = cache.cachedImage(
                sessionID: sessionID,
                cacheURL: fixtureURL,
                loader: CapturePreviewImageCache.loadUncachedImage(from:)
            )
            XCTAssertNotNil(image)
            _ = image?.size
        }

        let speedup = baseline.totalMilliseconds / max(warmCache.totalMilliseconds, 0.001)
        print(
            String(
                format: "Capture preview benchmark [repeated-load]: direct=%.2fms warmCache=%.2fms speedup=%.2fx iterations=%d",
                baseline.totalMilliseconds,
                warmCache.totalMilliseconds,
                speedup,
                benchmarkIterations
            )
        )

        XCTAssertGreaterThan(baseline.totalMilliseconds, warmCache.totalMilliseconds)
        XCTAssertGreaterThan(
            speedup,
            5,
            "Expected warm-cache preview loads to materially reduce repeated image decode/load cost."
        )
    }

    private func benchmark(
        label: String,
        operation: () -> Void
    ) -> BenchmarkResult {
        var totalMilliseconds = 0.0

        for _ in 0..<benchmarkIterations {
            let startedAt = CFAbsoluteTimeGetCurrent()
            autoreleasepool(invoking: operation)
            totalMilliseconds += (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
        }

        let averageMilliseconds = totalMilliseconds / Double(benchmarkIterations)
        print(
            String(
                format: "Capture preview benchmark [%@]: total=%.2fms avg=%.2fms iterations=%d",
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

    private func makeFixtureImage(at url: URL, size: NSSize) throws {
        let image = NSImage(size: size)
        image.lockFocus()

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.19, alpha: 1),
            NSColor(calibratedRed: 0.87, green: 0.59, blue: 0.24, alpha: 1),
        ])!
        gradient.draw(in: NSRect(origin: .zero, size: size), angle: -28)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 88, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
        ]
        NSString(string: "Backtick\nCapture Preview").draw(
            in: NSRect(x: 96, y: 140, width: size.width - 192, height: size.height - 280),
            withAttributes: attributes
        )

        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "CapturePreviewImagePerformanceTests", code: 1)
        }

        try png.write(to: url)
    }
}

private struct BenchmarkResult {
    let totalMilliseconds: Double
    let averageMilliseconds: Double
    let iterationCount: Int
}
