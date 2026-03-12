import SwiftUI

extension PromptCueSettingsView {
    func rowNote(_ text: String) -> some View {
        Text(text)
            .font(SettingsTokens.Typography.supporting)
            .foregroundStyle(SettingsSemanticTokens.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    func binding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { get() },
            set: { newValue in
                set(newValue)
            }
        )
    }
}
