import KeyboardShortcuts
import SwiftUI

@MainActor
struct PromptCueSettingsView: View {
    @ObservedObject private var screenshotSettingsModel: ScreenshotSettingsModel

    init(screenshotSettingsModel: ScreenshotSettingsModel) {
        self.screenshotSettingsModel = screenshotSettingsModel
    }

    init() {
        self.screenshotSettingsModel = ScreenshotSettingsModel()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrimitiveTokens.Space.lg) {
                shortcutsSection
                screenshotsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PrimitiveTokens.Space.xl)
        }
        .frame(
            width: AppUIConstants.settingsPanelWidth,
            height: AppUIConstants.settingsPanelHeight
        )
        .onAppear {
            screenshotSettingsModel.refresh()
        }
    }

    private var shortcutsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: PrimitiveTokens.Space.md) {
                KeyboardShortcuts.Recorder("Quick Capture", name: .quickCapture)
                KeyboardShortcuts.Recorder("Show Stack View", name: .openStackView)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, PrimitiveTokens.Space.xxs)
        } label: {
            sectionHeader(
                title: "Shortcuts",
                subtitle: "Capture and stack shortcuts can be changed here."
            )
        }
    }

    private var screenshotsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: PrimitiveTokens.Space.md) {
                switch screenshotSettingsModel.accessState {
                case .notConfigured:
                    stateBlock(
                        title: "No screenshot folder connected",
                        detail: unconfiguredDetail
                    )

                    Button("Choose Folder…") {
                        screenshotSettingsModel.chooseFolder()
                    }
                case let .connected(_, displayPath):
                    stateBlock(
                        title: "Connected screenshot folder",
                        detail: displayPath
                    )

                    HStack(spacing: PrimitiveTokens.Space.sm) {
                        Button("Change…") {
                            screenshotSettingsModel.chooseFolder()
                        }

                        Button("Reveal in Finder") {
                            screenshotSettingsModel.revealFolderInFinder()
                        }

                        Button("Disconnect") {
                            screenshotSettingsModel.clearFolder()
                        }
                    }
                case let .needsReconnect(lastKnownDisplayPath):
                    stateBlock(
                        title: "Reconnect screenshot folder",
                        detail: "Prompt Cue remembers \(lastKnownDisplayPath), but access needs to be approved again."
                    )

                    HStack(spacing: PrimitiveTokens.Space.sm) {
                        Button("Reconnect…") {
                            screenshotSettingsModel.reconnectFolder()
                        }

                        Button("Clear") {
                            screenshotSettingsModel.clearFolder()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, PrimitiveTokens.Space.xxs)
        } label: {
            sectionHeader(
                title: "Screenshots",
                subtitle: "Auto-attach only checks the folder you explicitly approve."
            )
        }
    }

    private var unconfiguredDetail: String {
        if let suggestedSystemPath = screenshotSettingsModel.suggestedSystemPath {
            return "System screenshots often save to \(suggestedSystemPath). Choose that folder to enable auto-attach."
        }

        return "Choose the folder Prompt Cue should watch for recent screenshots."
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxxs) {
            Text(title)
                .font(PrimitiveTokens.Typography.bodyStrong)
                .foregroundStyle(SemanticTokens.Text.primary)

            Text(subtitle)
                .font(PrimitiveTokens.Typography.meta)
                .foregroundStyle(SemanticTokens.Text.secondary)
        }
    }

    private func stateBlock(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxs) {
            Text(title)
                .font(PrimitiveTokens.Typography.bodyStrong)
                .foregroundStyle(SemanticTokens.Text.primary)

            Text(detail)
                .font(PrimitiveTokens.Typography.body)
                .foregroundStyle(SemanticTokens.Text.secondary)
                .textSelection(.enabled)
        }
    }
}
