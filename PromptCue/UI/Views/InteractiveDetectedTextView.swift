import PromptCueCore
import SwiftUI

struct InteractiveDetectedTextView: View {
    let text: String
    let classification: ContentClassification
    let baseColor: Color
    let onOpenDetected: () -> Void

    @State private var isSpanHovered = false
    @State private var isCursorPushed = false

    var body: some View {
        if let span = classification.span, classification.primaryType != .plain {
            buildSegmentedText(span: span)
        } else {
            plainText
        }
    }

    private var plainText: some View {
        Text(text)
            .font(PrimitiveTokens.Typography.body)
            .foregroundStyle(baseColor)
            .multilineTextAlignment(.leading)
            .lineSpacing(PrimitiveTokens.Space.xxxs)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var openActionLabel: String {
        classification.primaryType == .link ? "Open link" : "Reveal in Finder"
    }

    @ViewBuilder
    private func buildSegmentedText(span: DetectedSpan) -> some View {
        let displayText = resolveDisplayText(span: span)
        let isInteractive = classification.primaryType == .link || classification.primaryType == .path
        let before = text[text.startIndex..<span.range.lowerBound]
        let after = text[span.range.upperBound..<text.endIndex]

        let concatenated = beforeSegment(before)
            + detectedSegment(displayText, interactive: isInteractive)
            + afterSegment(after)

        if isInteractive {
            VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxs) {
                concatenated
                    .font(PrimitiveTokens.Typography.body)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(PrimitiveTokens.Space.xxxs)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSpanHovered {
                    Button(action: onOpenDetected) {
                        HStack(spacing: PrimitiveTokens.Space.xxs) {
                            Text(openActionLabel)
                            Image(systemName: "arrow.up.right")
                        }
                        .font(PrimitiveTokens.Typography.meta)
                        .foregroundStyle(spanRestingColor)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    if !isSpanHovered {
                        withAnimation(.easeOut(duration: PrimitiveTokens.Motion.quick)) {
                            isSpanHovered = true
                        }
                    }
                    if !isCursorPushed {
                        NSCursor.pointingHand.push()
                        isCursorPushed = true
                    }
                case .ended:
                    if isSpanHovered {
                        withAnimation(.easeOut(duration: PrimitiveTokens.Motion.quick)) {
                            isSpanHovered = false
                        }
                    }
                    if isCursorPushed {
                        NSCursor.pop()
                        isCursorPushed = false
                    }
                }
            }
            .onDisappear {
                if isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
        } else {
            concatenated
                .font(PrimitiveTokens.Typography.body)
                .multilineTextAlignment(.leading)
                .lineSpacing(PrimitiveTokens.Space.xxxs)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func beforeSegment(_ segment: Substring) -> Text {
        guard !segment.isEmpty else { return Text("") }
        return Text(segment)
            .foregroundStyle(baseColor)
    }

    private func detectedSegment(_ segment: String, interactive: Bool) -> Text {
        if interactive {
            return Text(segment)
                .foregroundStyle(isSpanHovered ? spanHoverColor : spanRestingColor)
                .underline(isSpanHovered, color: SemanticTokens.Classification.interactiveHoverUnderline)
        }

        return Text(segment)
            .foregroundStyle(SemanticTokens.Classification.secretText)
    }

    private func afterSegment(_ segment: Substring) -> Text {
        guard !segment.isEmpty else { return Text("") }
        return Text(segment)
            .foregroundStyle(baseColor)
    }

    private var spanRestingColor: Color {
        switch classification.primaryType {
        case .link: return SemanticTokens.Classification.interactiveText
        case .path: return SemanticTokens.Classification.interactiveText
        default: return baseColor
        }
    }

    private var spanHoverColor: Color {
        switch classification.primaryType {
        case .link: return SemanticTokens.Classification.interactiveHoverText
        case .path: return SemanticTokens.Classification.interactiveHoverText
        default: return baseColor
        }
    }

    private func resolveDisplayText(span: DetectedSpan) -> String {
        if classification.primaryType == .secret {
            return SecretMasker.mask(span.matchedText)
        }
        return span.matchedText
    }
}
