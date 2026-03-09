import KeyboardShortcuts
import PromptCueCore

@MainActor
final class HotKeyCenter {
    func registerDefaultShortcuts(
        onCapture: @escaping () -> Void,
        onOpenStackView: @escaping () -> Void
    ) {
        KeyboardShortcuts.removeAllHandlers()

        KeyboardShortcuts.onKeyUp(for: .quickCapture) {
            onCapture()
        }

        KeyboardShortcuts.onKeyUp(for: .openStackView) {
            onOpenStackView()
        }
    }

    func unregisterAll() {
        KeyboardShortcuts.removeAllHandlers()
    }
}
