import SwiftUI

extension PromptCueSettingsView {
    var stackPage: some View {
        settingsScrollPage {
            stackSections
        }
    }

    @ViewBuilder
    private var stackSections: some View {
        SettingsSection(title: "Retention") {
            SettingsRows {
                SettingsDetailGroupRow("Card Lifetime", showsDivider: false) {
                    VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxs) {
                        Toggle(
                            "Auto-expire stack cards after 8 hours",
                            isOn: autoExpireEnabledBinding
                        )
                        .toggleStyle(.checkbox)

                        rowNote("Cards stay until you delete them unless auto-expire is enabled.")
                        rowNote("Off by default. Turn this on to restore the original 8-hour cleanup behavior.")
                    }
                }
            }
        }

        SettingsSection(
            title: "AI Export Tail",
            footer: "Saved cards stay unchanged. The tail is added only when you copy or export."
        ) {
            SettingsRows {
                SettingsDetailGroupRow("Behavior") {
                    VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxs) {
                        Toggle(
                            "Append AI export tail",
                            isOn: exportTailEnabledBinding
                        )
                        .toggleStyle(.checkbox)

                        rowNote("Append your reusable instruction block to copied text without modifying saved cards.")
                    }
                }

                SettingsLongFormGroupRow("Tail Text") {
                    SettingsInlinePanel {
                        TextEditor(text: exportTailTextBinding)
                        .font(PrimitiveTokens.Typography.body)
                        .foregroundStyle(SemanticTokens.Text.primary)
                        .scrollContentBackground(.hidden)
                        .frame(
                            minHeight: PanelMetrics.settingsExportTailEditorMinHeight,
                            maxHeight: PanelMetrics.settingsExportTailEditorMaxHeight
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                SettingsLongFormGroupRow(
                    "Preview",
                    showsDivider: false,
                    actionTitle: "Reset to Default",
                    action: exportTailSettingsModel.resetToDefault
                ) {
                    SettingsInlinePanel {
                        Text(exportTailSettingsModel.previewText)
                            .font(PrimitiveTokens.Typography.body)
                            .foregroundStyle(SemanticTokens.Text.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var autoExpireEnabledBinding: Binding<Bool> {
        binding(
            get: { retentionSettingsModel.isAutoExpireEnabled },
            set: retentionSettingsModel.updateAutoExpireEnabled
        )
    }

    private var exportTailEnabledBinding: Binding<Bool> {
        binding(
            get: { exportTailSettingsModel.isEnabled },
            set: exportTailSettingsModel.updateEnabled
        )
    }

    private var exportTailTextBinding: Binding<String> {
        binding(
            get: { exportTailSettingsModel.suffixText },
            set: exportTailSettingsModel.updateSuffixText
        )
    }
}
