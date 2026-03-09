import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let quickCapture = Self(
        "quickCapture",
        default: .init(.backtick, modifiers: [.command])
    )

    static let openStackView = Self(
        "openStackView",
        default: .init(.two, modifiers: [.command])
    )
}
