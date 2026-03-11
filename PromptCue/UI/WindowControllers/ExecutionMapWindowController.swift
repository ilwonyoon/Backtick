import AppKit
import SwiftUI

private enum ExecutionMapWindowMetrics {
    static let width: CGFloat = 1180
    static let height: CGFloat = 760
    static let minimumWidth: CGFloat = 940
    static let minimumHeight: CGFloat = 640
}

@MainActor
final class ExecutionMapWindowController: NSObject, NSWindowDelegate {
    private let model: ExecutionMapModel
    private var window: NSWindow?

    init(model: ExecutionMapModel) {
        self.model = model
        super.init()
    }

    func show() {
        model.refresh()
        let window = window ?? makeWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applyAppearance(_ appearance: NSAppearance?) {
        window?.appearance = appearance
        window?.invalidateShadow()
        window?.contentView?.needsDisplay = true
        window?.contentView?.subviews.forEach { $0.needsDisplay = true }
    }

    private func makeWindow() -> NSWindow {
        let frame = NSRect(
            x: 0,
            y: 0,
            width: ExecutionMapWindowMetrics.width,
            height: ExecutionMapWindowMetrics.height
        )
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Backtick Execution Map"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(
            width: ExecutionMapWindowMetrics.minimumWidth,
            height: ExecutionMapWindowMetrics.minimumHeight
        )
        window.center()
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: ExecutionMapView(model: model))

        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window else {
            return
        }

        window.orderOut(nil)
    }
}
