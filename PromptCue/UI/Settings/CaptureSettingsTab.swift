import SwiftUI

extension PromptCueSettingsView {
    var capturePage: some View {
        settingsScrollPage {
            captureSections
        }
    }

    @ViewBuilder
    private var captureSections: some View {
        SettingsSection(
            title: "Screenshots",
            footer: "Auto-attach only checks the screenshot folder you explicitly approve."
        ) {
            SettingsRows {
                SettingsTwoColumnGroupRow("Status") {
                    SettingsStatusBadge(
                        title: screenshotStatusTitle,
                        tone: screenshotStatusBadgeTone
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsDetailGroupRow("Folder", showsDivider: false) {
                    Text(screenshotStatusDetail)
                        .font(PrimitiveTokens.Typography.body)
                        .foregroundStyle(SemanticTokens.Text.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } actions: {
                    Group {
                        primaryScreenshotButton

                        if case .connected = screenshotSettingsModel.accessState {
                            Button("Reveal in Finder") {
                                screenshotSettingsModel.revealFolderInFinder()
                            }

                            Button("Disconnect") {
                                screenshotSettingsModel.clearFolder()
                            }
                        }

                        if case .needsReconnect = screenshotSettingsModel.accessState {
                            Button("Clear") {
                                screenshotSettingsModel.clearFolder()
                            }
                        }
                    }
                }
            }
        }
    }

    private var screenshotStatusTitle: String {
        switch screenshotSettingsModel.accessState {
        case .notConfigured:
            return "Not connected"
        case .connected:
            return "Connected"
        case .needsReconnect:
            return "Needs reconnect"
        }
    }

    private var screenshotStatusDetail: String {
        switch screenshotSettingsModel.accessState {
        case .notConfigured:
            if let suggestedSystemPath = screenshotSettingsModel.suggestedSystemPath {
                return "System screenshots often save to \(suggestedSystemPath). Choose that folder to enable auto-attach."
            }

            return "Choose the folder Backtick should watch for recent screenshots."
        case let .connected(_, displayPath):
            return displayPath
        case let .needsReconnect(lastKnownDisplayPath):
            return "Backtick remembers \(lastKnownDisplayPath), but access needs to be approved again."
        }
    }

    @ViewBuilder
    private var primaryScreenshotButton: some View {
        switch screenshotSettingsModel.accessState {
        case .notConfigured:
            Button("Choose Folder…") {
                screenshotSettingsModel.chooseFolder()
            }
        case .connected:
            Button("Change…") {
                screenshotSettingsModel.chooseFolder()
            }
        case .needsReconnect:
            Button("Reconnect…") {
                screenshotSettingsModel.reconnectFolder()
            }
        }
    }

    private var screenshotStatusBadgeTone: SettingsStatusBadge.Tone {
        switch screenshotSettingsModel.accessState {
        case .notConfigured:
            return .neutral
        case .connected:
            return .success
        case .needsReconnect:
            return .warning
        }
    }
}
