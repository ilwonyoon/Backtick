import KeyboardShortcuts
import SwiftUI

extension PromptCueSettingsView {
    var generalPage: some View {
        settingsScrollPage {
            generalSections
        }
    }

    @ViewBuilder
    private var generalSections: some View {
        SettingsSection(
            title: "Appearance",
            footer: "Choose whether Backtick follows the system theme or forces a specific mode."
        ) {
            SettingsRows {
                SettingsTwoColumnGroupRow(
                    "Theme",
                    showsDivider: false,
                    contentAlignment: .trailing
                ) {
                    Picker(
                        "",
                        selection: binding(
                            get: { appearanceSettingsModel.mode },
                            set: { appearanceSettingsModel.updateMode($0) }
                        )
                    ) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220, alignment: .trailing)
                }
            }
        }

        SettingsSection(
            title: "Shortcuts",
            footer: "These shortcuts work globally."
        ) {
            SettingsRows {
                SettingsTwoColumnGroupRow("Quick Capture", contentAlignment: .trailing) {
                    KeyboardShortcuts.Recorder(for: .quickCapture)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                SettingsTwoColumnGroupRow(
                    "Show Stack",
                    showsDivider: false,
                    contentAlignment: .trailing
                ) {
                    KeyboardShortcuts.Recorder(for: .toggleStackPanel)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }

        SettingsSection(
            title: "iCloud Sync",
            footer: "Sync cards across your Macs via iCloud. Screenshots stay local."
        ) {
            SettingsRows {
                SettingsTwoColumnGroupRow("Sync", verticalAlignment: .top) {
                    VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxs) {
                        Toggle(
                            "Enable iCloud sync",
                            isOn: binding(
                                get: { cloudSyncSettingsModel.isSyncEnabled },
                                set: cloudSyncSettingsModel.updateSyncEnabled
                            )
                        )
                        .toggleStyle(.checkbox)

                        rowNote("Cards sync automatically between Macs signed into the same Apple ID.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsTwoColumnGroupRow("Status", showsDivider: false) {
                    SettingsStatusBadge(
                        title: cloudSyncSettingsModel.syncStatusText,
                        tone: cloudSyncStatusBadgeTone
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var cloudSyncStatusBadgeTone: SettingsStatusBadge.Tone {
        if cloudSyncSettingsModel.syncError != nil {
            return .warning
        }

        return cloudSyncSettingsModel.isSyncEnabled ? .success : .neutral
    }
}
