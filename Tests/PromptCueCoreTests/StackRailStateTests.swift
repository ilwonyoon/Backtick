import Testing
@testable import PromptCueCore

struct StackRailStateTests {
    @Test
    func headerShowsPromptCount() {
        let state = StackRailState(activeCount: 4, copiedCount: 2, stagedCount: 0)

        #expect(state.headerTitle == "4 prompts")
    }

    @Test
    func headerShowsSingularPrompt() {
        let state = StackRailState(activeCount: 1, copiedCount: 0, stagedCount: 0)

        #expect(state.headerTitle == "1 prompt")
    }

    @Test
    func feedbackUsesCopiedForImmediateAction() {
        let one = StackRailState(activeCount: 4, copiedCount: 2, stagedCount: 1)
        let many = StackRailState(activeCount: 4, copiedCount: 2, stagedCount: 3)

        #expect(one.actionFeedbackLabel == "1 Copied")
        #expect(many.actionFeedbackLabel == "3 Copied")
    }
}
