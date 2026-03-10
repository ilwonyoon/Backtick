import AppKit
import XCTest
@testable import Prompt_Cue

@MainActor
final class CapturePanelResizePerformanceTests: XCTestCase {
    private let benchmarkRunEnabled: Bool = {
#if PROMPTCUE_RUN_PERF_BENCHMARKS
        true
#else
        ProcessInfo.processInfo.environment["PROMPTCUE_RUN_PERF_BENCHMARKS"] == "1"
#endif
    }()
    private let callbackIterations = {
        if let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_CAPTURE_RESIZE_CALLBACK_ITERATIONS"],
           let parsedValue = Int(rawValue),
           parsedValue > 0 {
            return parsedValue
        }

        return 2_400
    }()
    private let frameIterations = {
        if let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_CAPTURE_RESIZE_FRAME_ITERATIONS"],
           let parsedValue = Int(rawValue),
           parsedValue > 0 {
            return parsedValue
        }

        return 2_400
    }()

    func testRepeatedPreferredHeightCallbackBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run capture resize benchmarks."
        )

        let initialFrame = NSRect(x: 240, y: 360, width: 640, height: 220)
        let nextHeight: CGFloat = 388
        let targetHeights = [nextHeight] + Array(repeating: nextHeight, count: max(callbackIterations - 1, 0))

        let baseline = benchmarkPreferredHeightCallback(
            initialFrame: initialFrame,
            targetHeights: targetHeights,
            guarded: false
        )
        let guarded = benchmarkPreferredHeightCallback(
            initialFrame: initialFrame,
            targetHeights: targetHeights,
            guarded: true
        )

        let speedup = baseline.totalMilliseconds / max(guarded.totalMilliseconds, 0.001)
        print(
            String(
                format: "Capture resize benchmark [preferred-height-callback]: unguarded=%.2fms guarded=%.2fms speedup=%.2fx iterations=%d emitted=%d skipped=%d",
                baseline.totalMilliseconds,
                guarded.totalMilliseconds,
                speedup,
                callbackIterations,
                guarded.emittedHeightCount,
                guarded.skippedHeightCount
            )
        )

        XCTAssertGreaterThan(baseline.totalMilliseconds, guarded.totalMilliseconds)
        XCTAssertEqual(guarded.emittedHeightCount, 1)
        XCTAssertEqual(guarded.skippedHeightCount, max(callbackIterations - 1, 0))
    }

    func testRepeatedPanelFrameApplyBenchmark() throws {
        try XCTSkipUnless(
            benchmarkRunEnabled,
            "Compile with -DPROMPTCUE_RUN_PERF_BENCHMARKS or set PROMPTCUE_RUN_PERF_BENCHMARKS=1 to run capture resize benchmarks."
        )

        let initialFrame = NSRect(x: 240, y: 360, width: 640, height: 220)
        let changedFrame = NSRect(x: 240, y: 192, width: 640, height: 388)
        let targetFrames = [changedFrame] + Array(repeating: changedFrame, count: max(frameIterations - 1, 0))

        let baseline = benchmarkFrameApply(
            initialFrame: initialFrame,
            targetFrames: targetFrames,
            guarded: false
        )
        let guarded = benchmarkFrameApply(
            initialFrame: initialFrame,
            targetFrames: targetFrames,
            guarded: true
        )

        let speedup = baseline.totalMilliseconds / max(guarded.totalMilliseconds, 0.001)
        print(
            String(
                format: "Capture resize benchmark [panel-frame-apply]: unguarded=%.2fms guarded=%.2fms speedup=%.2fx iterations=%d applied=%d skipped=%d",
                baseline.totalMilliseconds,
                guarded.totalMilliseconds,
                speedup,
                frameIterations,
                guarded.appliedFrameCount,
                guarded.skippedFrameCount
            )
        )

        XCTAssertGreaterThan(baseline.totalMilliseconds, guarded.totalMilliseconds)
        XCTAssertEqual(guarded.appliedFrameCount, 1)
        XCTAssertEqual(guarded.skippedFrameCount, max(frameIterations - 1, 0))
    }

    private func benchmarkPreferredHeightCallback(
        initialFrame: NSRect,
        targetHeights: [CGFloat],
        guarded: Bool
    ) -> CapturePanelPreferredHeightUpdateMetrics {
        let panel = makeBenchmarkPanel(initialFrame: initialFrame)

        return CapturePanelPreferredHeightGuard.benchmark(
            initialHeight: initialFrame.height,
            targetHeights: targetHeights,
            guarded: guarded
        ) { height in
            var targetFrame = initialFrame
            targetFrame.origin.y = initialFrame.maxY - height
            targetFrame.size.height = height
            panel.setFrame(targetFrame, display: false, animate: false)
        }
    }

    private func benchmarkFrameApply(
        initialFrame: NSRect,
        targetFrames: [NSRect],
        guarded: Bool
    ) -> CapturePanelFrameUpdateMetrics {
        let panel = makeBenchmarkPanel(initialFrame: initialFrame)

        return CapturePanelFrameUpdateGuard.benchmark(
            initialFrame: initialFrame,
            targetFrames: targetFrames,
            guarded: guarded
        ) { frame in
            panel.setFrame(frame, display: false, animate: false)
        }
    }

    private func makeBenchmarkPanel(initialFrame: NSRect) -> NSPanel {
        _ = NSApplication.shared

        let panel = NSPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.orderOut(nil)
        return panel
    }
}
