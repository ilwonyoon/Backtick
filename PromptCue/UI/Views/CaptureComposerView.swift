import AppKit
import PromptCueCore
import SwiftUI

struct CaptureComposerView: View {
    @ObservedObject var model: AppModel
    let onSubmitSuccess: () -> Void

    init(model: AppModel, onSubmitSuccess: @escaping () -> Void = {}) {
        self.model = model
        self.onSubmitSuccess = onSubmitSuccess
    }

    var body: some View {
        SearchFieldSurface {
            VStack(alignment: .leading, spacing: PrimitiveTokens.Space.sm) {
                if shouldShowScreenshotSlot {
                    screenshotPreview(for: recentScreenshotAttachment)
                }

                cueEditor
            }
        }
        .frame(width: AppUIConstants.captureSurfaceWidth, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(PrimitiveTokens.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            model.refreshPendingScreenshot()
        }
        .onExitCommand {
            closePanel()
        }
    }

    private var trimmedDraft: String {
        model.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var recentScreenshotAttachment: ScreenshotAttachment? {
        model.pendingScreenshotAttachment
    }

    private var shouldShowScreenshotSlot: Bool {
        recentScreenshotAttachment != nil || model.isAwaitingRecentScreenshot
    }

    private var cueEditor: some View {
        let editorVisibleHeight = max(AppUIConstants.captureTextLineHeight, model.draftEditorContentHeight)

        return CueTextEditor(
            text: $model.draftText,
            maxContentHeight: AppUIConstants.captureEditorMaxHeight,
            onHeightChange: { height in
                if abs(model.draftEditorContentHeight - height) > 0.5 {
                    model.draftEditorContentHeight = height
                }
            },
            onSubmit: {
                if model.submitCapture() {
                    onSubmitSuccess()
                }
            },
            onCancel: closePanel
        )
        .frame(
            maxWidth: .infinity,
            minHeight: editorVisibleHeight,
            maxHeight: editorVisibleHeight,
            alignment: .topLeading
        )
        .overlay(alignment: .topLeading) {
            if trimmedDraft.isEmpty {
                Text("Type and press Enter to save")
                    .font(PrimitiveTokens.Typography.captureInput)
                    .foregroundStyle(SemanticTokens.Text.secondary)
                    .opacity(PrimitiveTokens.Opacity.soft)
                    .allowsHitTesting(false)
            }
        }
    }

    private func screenshotPreview(for attachment: ScreenshotAttachment?) -> some View {
        ZStack(alignment: .topTrailing) {
            if let attachment {
                LocalImageThumbnail(
                    url: URL(fileURLWithPath: attachment.path),
                    width: PrimitiveTokens.Size.captureAttachmentPreviewSize,
                    height: PrimitiveTokens.Size.captureAttachmentPreviewSize
                )
            } else {
                screenshotPlaceholder
            }

            Button(action: clearRecentScreenshot) {
                Image(systemName: "xmark.circle.fill")
                    .font(PrimitiveTokens.Typography.accessoryIcon)
                    .foregroundStyle(SemanticTokens.Text.primary)
                    .promptCueFloatingControlShadow()
            }
            .buttonStyle(.plain)
            .help("Remove recent screenshot")
            .accessibilityLabel("Remove recent screenshot")
            .padding(.top, PrimitiveTokens.Space.xs)
            .padding(.trailing, PrimitiveTokens.Space.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clearRecentScreenshot() {
        model.dismissPendingScreenshot()
    }

    private var screenshotPlaceholder: some View {
        RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
            .fill(SemanticTokens.Surface.accentFill.opacity(PrimitiveTokens.Opacity.faint))
            .frame(
                width: PrimitiveTokens.Size.captureAttachmentPreviewSize,
                height: PrimitiveTokens.Size.captureAttachmentPreviewSize
            )
            .overlay {
                ProgressView()
                    .controlSize(.small)
            }
            .overlay {
                RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
                    .stroke(SemanticTokens.Border.subtle)
            }
    }

    private func closePanel() {
        model.clearDraft()
        NSApp.keyWindow?.cancelOperation(nil)
    }
}
