import Foundation

public struct StackRailState: Equatable, Sendable {
    public let activeCount: Int
    public let copiedCount: Int
    public let stagedCount: Int

    public init(
        activeCount: Int,
        copiedCount: Int,
        stagedCount: Int
    ) {
        self.activeCount = max(0, activeCount)
        self.copiedCount = max(0, copiedCount)
        self.stagedCount = max(0, stagedCount)
    }

    public var summaryLabel: String {
        let promptsPart = activeCount == 1 ? "1 prompt" : "\(activeCount) prompts"
        if copiedCount > 0 {
            return "\(promptsPart) · \(copiedCount) copied"
        }
        return promptsPart
    }

    public var headerTitle: String {
        let count = activeCount
        return count == 1 ? "1 prompt" : "\(count) prompts"
    }

    public var actionFeedbackLabel: String? {
        guard stagedCount > 0 else {
            return nil
        }

        return "\(stagedCount) Copied"
    }
}
