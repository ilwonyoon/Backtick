import AppKit
import Foundation
import OSLog

@MainActor
enum PerformanceTrace {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.promptcue.promptcue"
    private static let signposter = OSSignposter(subsystem: subsystem, category: "Performance")
    private static let logger = Logger(subsystem: subsystem, category: "Performance")

    private struct PendingStackOpenTrace {
        let state: OSSignpostIntervalState
        let startedAt: CFAbsoluteTime
        var lastMarkedAt: CFAbsoluteTime
    }

    private struct PendingCaptureOpenTrace {
        let state: OSSignpostIntervalState
        let startedAt: CFAbsoluteTime
        var lastMarkedAt: CFAbsoluteTime
    }

    private struct PendingCaptureSubmitCloseTrace {
        let state: OSSignpostIntervalState
        let startedAt: CFAbsoluteTime
        var lastMarkedAt: CFAbsoluteTime
    }

    private static var pendingStackOpenTrace: PendingStackOpenTrace?
    private static var pendingCaptureOpenTrace: PendingCaptureOpenTrace?
    private static var pendingCaptureSubmitCloseTrace: PendingCaptureSubmitCloseTrace?

    static var shouldTraceStackToggleOnStart: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_STACK_TOGGLE_ON_START"] == "1"
    }

    static var stackToggleDelayNanoseconds: UInt64 {
        guard let rawValue = ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_STACK_TOGGLE_DELAY_MS"],
              let milliseconds = UInt64(rawValue)
        else {
            return 250_000_000
        }

        return milliseconds * 1_000_000
    }

    static var shouldTraceCaptureToggleOnStart: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_CAPTURE_TOGGLE_ON_START"] == "1"
    }

    static var captureToggleDelayNanoseconds: UInt64 {
        nanoseconds(
            for: "PROMPTCUE_TRACE_CAPTURE_TOGGLE_DELAY_MS",
            defaultNanoseconds: 250_000_000
        )
    }

    static var shouldTraceCaptureSubmitCloseOnStart: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_CAPTURE_SUBMIT_CLOSE_ON_START"] == "1"
    }

    static var captureSubmitCloseDelayNanoseconds: UInt64 {
        nanoseconds(
            for: "PROMPTCUE_TRACE_CAPTURE_SUBMIT_CLOSE_DELAY_MS",
            defaultNanoseconds: 600_000_000
        )
    }

    private static var shouldAutoQuitAfterStackTrace: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_AUTO_QUIT_AFTER_STACK"] == "1"
    }

    private static var shouldAutoQuitAfterCaptureOpenTrace: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_AUTO_QUIT_AFTER_CAPTURE_OPEN"] == "1"
    }

    private static var shouldAutoQuitAfterCaptureSubmitCloseTrace: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_AUTO_QUIT_AFTER_CAPTURE_SUBMIT_CLOSE"] == "1"
    }

    private static var shouldPrintStackTraceMetric: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_STDOUT_METRIC"] == "1"
    }

    private static var shouldPrintStackPhaseMetrics: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_STACK_PHASES"] == "1"
    }

    private static var shouldPrintCaptureOpenMetric: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_CAPTURE_OPEN_STDOUT_METRIC"] == "1"
    }

    private static var shouldPrintCaptureSubmitCloseMetric: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_CAPTURE_SUBMIT_CLOSE_STDOUT_METRIC"] == "1"
    }

    private static var shouldPrintCapturePhaseMetrics: Bool {
        ProcessInfo.processInfo.environment["PROMPTCUE_TRACE_CAPTURE_PHASES"] == "1"
    }

    static var shouldMeasureCaptureOpen: Bool {
        shouldTraceCaptureToggleOnStart
            || shouldAutoQuitAfterCaptureOpenTrace
            || shouldPrintCaptureOpenMetric
            || shouldPrintCapturePhaseMetrics
    }

    static var shouldMeasureCaptureSubmitClose: Bool {
        shouldTraceCaptureSubmitCloseOnStart
            || shouldAutoQuitAfterCaptureSubmitCloseTrace
            || shouldPrintCaptureSubmitCloseMetric
            || shouldPrintCapturePhaseMetrics
    }

    static func beginStackOpenTrace() {
        guard pendingStackOpenTrace == nil else {
            return
        }

        let startedAt = CFAbsoluteTimeGetCurrent()

        pendingStackOpenTrace = PendingStackOpenTrace(
            state: signposter.beginInterval("StackOpenFirstFrame"),
            startedAt: startedAt,
            lastMarkedAt: startedAt
        )
        signposter.emitEvent("StackOpenRequested")
    }

    static func markStackOpenPhase(_ phase: String) {
        guard var pendingStackOpenTrace else {
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        let totalMilliseconds = (now - pendingStackOpenTrace.startedAt) * 1_000
        let deltaMilliseconds = (now - pendingStackOpenTrace.lastMarkedAt) * 1_000
        pendingStackOpenTrace.lastMarkedAt = now
        Self.pendingStackOpenTrace = pendingStackOpenTrace

        logger.info(
            "StackOpenPhase \(phase, privacy: .public) total_ms=\(totalMilliseconds, format: .fixed(precision: 2)) delta_ms=\(deltaMilliseconds, format: .fixed(precision: 2))"
        )

        if shouldPrintStackPhaseMetrics {
            let line = String(
                format: "PROMPTCUE_STACK_OPEN_PHASE=%@ TOTAL_MS=%.2f DELTA_MS=%.2f",
                phase,
                totalMilliseconds,
                deltaMilliseconds
            )
            print(line)
            fflush(stdout)
        }
    }

    static func completeStackOpenTraceIfNeeded() {
        guard let pendingStackOpenTrace else {
            return
        }

        Self.pendingStackOpenTrace = nil

        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - pendingStackOpenTrace.startedAt) * 1_000
        logger.info("StackOpenPhase first_frame_displayed total_ms=\(elapsedMilliseconds, format: .fixed(precision: 2))")
        if shouldPrintStackPhaseMetrics {
            let line = String(format: "PROMPTCUE_STACK_OPEN_PHASE=first_frame_displayed TOTAL_MS=%.2f", elapsedMilliseconds)
            print(line)
            fflush(stdout)
        }
        signposter.emitEvent("StackOpenFirstFrameDisplayed")
        signposter.endInterval("StackOpenFirstFrame", pendingStackOpenTrace.state)
        logger.info("StackOpenFirstFrame elapsed_ms=\(elapsedMilliseconds, format: .fixed(precision: 2))")

        if shouldPrintStackTraceMetric {
            let metricLine = String(format: "PROMPTCUE_STACK_OPEN_FIRST_FRAME_MS=%.2f", elapsedMilliseconds)
            print(metricLine)
            fflush(stdout)
        }

        scheduleTerminationIfNeeded(shouldAutoQuitAfterStackTrace)
    }

    static func beginCaptureOpenTrace() {
        guard shouldMeasureCaptureOpen, pendingCaptureOpenTrace == nil else {
            return
        }

        let startedAt = CFAbsoluteTimeGetCurrent()
        pendingCaptureOpenTrace = PendingCaptureOpenTrace(
            state: signposter.beginInterval("CaptureOpenFocusedEditor"),
            startedAt: startedAt,
            lastMarkedAt: startedAt
        )
        signposter.emitEvent("CaptureOpenRequested")
    }

    static func markCaptureOpenPhase(_ phase: String) {
        guard var pendingCaptureOpenTrace else {
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        let totalMilliseconds = (now - pendingCaptureOpenTrace.startedAt) * 1_000
        let deltaMilliseconds = (now - pendingCaptureOpenTrace.lastMarkedAt) * 1_000
        pendingCaptureOpenTrace.lastMarkedAt = now
        Self.pendingCaptureOpenTrace = pendingCaptureOpenTrace

        logger.info(
            "CaptureOpenPhase \(phase, privacy: .public) total_ms=\(totalMilliseconds, format: .fixed(precision: 2)) delta_ms=\(deltaMilliseconds, format: .fixed(precision: 2))"
        )

        if shouldPrintCapturePhaseMetrics {
            let line = String(
                format: "PROMPTCUE_CAPTURE_OPEN_PHASE=%@ TOTAL_MS=%.2f DELTA_MS=%.2f",
                phase,
                totalMilliseconds,
                deltaMilliseconds
            )
            print(line)
            fflush(stdout)
        }
    }

    static func completeCaptureOpenTraceIfNeeded() {
        guard let pendingCaptureOpenTrace else {
            return
        }

        Self.pendingCaptureOpenTrace = nil

        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - pendingCaptureOpenTrace.startedAt) * 1_000
        logger.info("CaptureOpenPhase focused_editor total_ms=\(elapsedMilliseconds, format: .fixed(precision: 2))")
        if shouldPrintCapturePhaseMetrics {
            let line = String(
                format: "PROMPTCUE_CAPTURE_OPEN_PHASE=focused_editor TOTAL_MS=%.2f",
                elapsedMilliseconds
            )
            print(line)
            fflush(stdout)
        }
        signposter.emitEvent("CaptureFocusedEditor")
        signposter.endInterval("CaptureOpenFocusedEditor", pendingCaptureOpenTrace.state)
        logger.info("CaptureOpenFocusedEditor elapsed_ms=\(elapsedMilliseconds, format: .fixed(precision: 2))")

        if shouldPrintCaptureOpenMetric {
            let metricLine = String(format: "PROMPTCUE_CAPTURE_OPEN_FOCUSED_EDITOR_MS=%.2f", elapsedMilliseconds)
            print(metricLine)
            fflush(stdout)
        }

        scheduleTerminationIfNeeded(shouldAutoQuitAfterCaptureOpenTrace)
    }

    static func cancelCaptureOpenTraceIfNeeded() {
        guard let pendingCaptureOpenTrace else {
            return
        }

        Self.pendingCaptureOpenTrace = nil
        signposter.endInterval("CaptureOpenFocusedEditor", pendingCaptureOpenTrace.state)
        logger.info("CaptureOpenFocusedEditor cancelled")
    }

    static func beginCaptureSubmitCloseTrace() {
        guard shouldMeasureCaptureSubmitClose, pendingCaptureSubmitCloseTrace == nil else {
            return
        }

        let startedAt = CFAbsoluteTimeGetCurrent()
        pendingCaptureSubmitCloseTrace = PendingCaptureSubmitCloseTrace(
            state: signposter.beginInterval("CaptureSubmitPanelClose"),
            startedAt: startedAt,
            lastMarkedAt: startedAt
        )
        signposter.emitEvent("CaptureSubmitRequested")
    }

    static func markCaptureSubmitClosePhase(_ phase: String) {
        guard var pendingCaptureSubmitCloseTrace else {
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        let totalMilliseconds = (now - pendingCaptureSubmitCloseTrace.startedAt) * 1_000
        let deltaMilliseconds = (now - pendingCaptureSubmitCloseTrace.lastMarkedAt) * 1_000
        pendingCaptureSubmitCloseTrace.lastMarkedAt = now
        Self.pendingCaptureSubmitCloseTrace = pendingCaptureSubmitCloseTrace

        logger.info(
            "CaptureSubmitClosePhase \(phase, privacy: .public) total_ms=\(totalMilliseconds, format: .fixed(precision: 2)) delta_ms=\(deltaMilliseconds, format: .fixed(precision: 2))"
        )

        if shouldPrintCapturePhaseMetrics {
            let line = String(
                format: "PROMPTCUE_CAPTURE_SUBMIT_CLOSE_PHASE=%@ TOTAL_MS=%.2f DELTA_MS=%.2f",
                phase,
                totalMilliseconds,
                deltaMilliseconds
            )
            print(line)
            fflush(stdout)
        }
    }

    static func completeCaptureSubmitCloseTraceIfNeeded() {
        guard let pendingCaptureSubmitCloseTrace else {
            return
        }

        Self.pendingCaptureSubmitCloseTrace = nil

        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - pendingCaptureSubmitCloseTrace.startedAt) * 1_000
        logger.info("CaptureSubmitClosePhase panel_closed total_ms=\(elapsedMilliseconds, format: .fixed(precision: 2))")
        if shouldPrintCapturePhaseMetrics {
            let line = String(
                format: "PROMPTCUE_CAPTURE_SUBMIT_CLOSE_PHASE=panel_closed TOTAL_MS=%.2f",
                elapsedMilliseconds
            )
            print(line)
            fflush(stdout)
        }
        signposter.emitEvent("CapturePanelClosedAfterSubmit")
        signposter.endInterval("CaptureSubmitPanelClose", pendingCaptureSubmitCloseTrace.state)
        logger.info("CaptureSubmitPanelClose elapsed_ms=\(elapsedMilliseconds, format: .fixed(precision: 2))")

        if shouldPrintCaptureSubmitCloseMetric {
            let metricLine = String(format: "PROMPTCUE_CAPTURE_SUBMIT_CLOSE_MS=%.2f", elapsedMilliseconds)
            print(metricLine)
            fflush(stdout)
        }

        scheduleTerminationIfNeeded(shouldAutoQuitAfterCaptureSubmitCloseTrace)
    }

    static func cancelCaptureSubmitCloseTraceIfNeeded() {
        guard let pendingCaptureSubmitCloseTrace else {
            return
        }

        Self.pendingCaptureSubmitCloseTrace = nil
        signposter.endInterval("CaptureSubmitPanelClose", pendingCaptureSubmitCloseTrace.state)
        logger.info("CaptureSubmitPanelClose cancelled")
    }

    private static func nanoseconds(
        for key: String,
        defaultNanoseconds: UInt64
    ) -> UInt64 {
        guard let rawValue = ProcessInfo.processInfo.environment[key],
              let milliseconds = UInt64(rawValue)
        else {
            return defaultNanoseconds
        }

        return milliseconds * 1_000_000
    }

    private static func scheduleTerminationIfNeeded(_ shouldTerminate: Bool) {
        guard shouldTerminate else {
            return
        }

        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }
}
