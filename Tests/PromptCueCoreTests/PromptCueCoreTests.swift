import Foundation
import Testing
@testable import PromptCueCore

struct PromptCueCoreTests {
    @Test
    func emptyDraftHasNoContent() {
        let draft = CaptureDraft()

        #expect(draft.hasContent == false)
    }

    @Test
    func textDraftHasContentWhenTrimmedTextExists() {
        let draft = CaptureDraft(text: "  mobile layout broken  ")

        #expect(draft.hasContent)
    }

    @Test
    func screenshotOnlyDraftHasContent() {
        let draft = CaptureDraft(recentScreenshot: ScreenshotAttachment(path: "/tmp/screenshot.png"))

        #expect(draft.hasContent)
    }

    @Test
    func screenshotAttachmentIdentityTracksFreshness() {
        let date = Date(timeIntervalSince1970: 1_000)
        let older = ScreenshotAttachment(path: "/tmp/screenshot.png", modifiedAt: date)
        let newer = ScreenshotAttachment(path: "/tmp/screenshot.png", modifiedAt: date.addingTimeInterval(1))

        #expect(older.identityKey != newer.identityKey)
    }

    @Test
    func captureCardExpiresAfterDefaultTTL() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let card = CaptureCard(text: "auth redirect incorrect", createdAt: createdAt)
        let justBeforeExpiry = createdAt.addingTimeInterval(CaptureCard.ttl - 1)
        let justAfterExpiry = createdAt.addingTimeInterval(CaptureCard.ttl + 1)

        #expect(card.isExpired(relativeTo: justBeforeExpiry) == false)
        #expect(card.isExpired(relativeTo: justAfterExpiry))
    }

    @Test
    func captureCardBuildsScreenshotURL() {
        let card = CaptureCard(
            bodyText: "screenshot attached",
            createdAt: .now,
            screenshotPath: "/tmp/example.png"
        )

        #expect(card.screenshotURL?.path == "/tmp/example.png")
    }

    @Test
    func captureCardTracksCopiedState() {
        let copiedAt = Date(timeIntervalSince1970: 2_000)
        let card = CaptureCard(text: "copied cue", createdAt: .now)
        let copied = card.markCopied(at: copiedAt)

        #expect(card.isCopied == false)
        #expect(copied.isCopied)
        #expect(copied.lastCopiedAt == copiedAt)
    }

    @Test
    func cardStackOrderingMovesCopiedCardsToBottom() {
        let oldest = Date(timeIntervalSince1970: 1_000)
        let newest = Date(timeIntervalSince1970: 2_000)
        let earlierCopy = Date(timeIntervalSince1970: 3_000)
        let laterCopy = Date(timeIntervalSince1970: 4_000)

        let freshCard = CaptureCard(text: "fresh", createdAt: newest)
        let olderCopiedCard = CaptureCard(
            text: "older copied",
            createdAt: oldest,
            lastCopiedAt: earlierCopy
        )
        let justCopiedCard = CaptureCard(
            text: "just copied",
            createdAt: newest.addingTimeInterval(10),
            lastCopiedAt: laterCopy
        )

        let ordered = CardStackOrdering.sort([justCopiedCard, olderCopiedCard, freshCard])

        #expect(ordered.map(\.text) == ["fresh", "older copied", "just copied"])
    }

    @Test
    func cardStackOrderingRespectsManualSortOrderWithinSection() {
        let top = CaptureCard(text: "top", createdAt: .now, sortOrder: 10)
        let bottom = CaptureCard(text: "bottom", createdAt: .now.addingTimeInterval(-10), sortOrder: 1)

        let ordered = CardStackOrdering.sort([bottom, top])

        #expect(ordered.map(\.text) == ["top", "bottom"])
    }

    @Test
    func exportFormatterBuildsBulletedClipboardPayloadInOrder() {
        let cards = [
            CaptureCard(text: "mobile layout broken", createdAt: .now),
            CaptureCard(text: "auth redirect incorrect", createdAt: .now),
            CaptureCard(text: "screenshot attached", createdAt: .now),
        ]

        let payload = ExportFormatter.string(for: cards)

        #expect(
            payload == """
            • mobile layout broken
            • auth redirect incorrect
            • screenshot attached
            """
        )
    }

    @Test
    func captureSuggestedTargetBuildsCompactDisplayLabel() {
        let target = CaptureSuggestedTarget(
            appName: "iTerm2",
            bundleIdentifier: "com.googlecode.iterm2",
            windowTitle: "feature/login - auth-service - very long detail title that should truncate",
            capturedAt: .now
        )

        #expect(target.displayLabel.hasPrefix("iTerm2 · feature/login - auth-service"))
        #expect(target.displayLabel.contains("…"))
    }

    @Test
    func captureSuggestedTargetPrefersRepositorySummaryWhenAvailable() {
        let target = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "api-shell",
            currentWorkingDirectory: "/Users/ilwonyoon/projects/auth-service",
            repositoryRoot: "/Users/ilwonyoon/projects/auth-service",
            repositoryName: "auth-service",
            branch: "feature/login",
            capturedAt: .now
        )

        #expect(target.projectDisplayName == "auth-service")
        #expect(target.projectSummaryText == "auth-service · feature/login")
        #expect(target.displayLabel == "auth-service · feature/login")
    }

    @Test
    func captureSuggestedTargetBuildsWorkspaceLabelFromWorktreeLeaf() {
        let target = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            currentWorkingDirectory: "/Users/ilwonyoon/projects/auth-service/.worktrees/login",
            repositoryRoot: "/Users/ilwonyoon/projects/auth-service",
            repositoryName: "auth-service",
            branch: "feature/login",
            capturedAt: .now
        )

        #expect(target.workspaceLabel == "auth-service/login")
        #expect(target.shortBranchLabel == "login")
        #expect(target.chooserSecondaryLabel == "Terminal · login")
    }

    @Test
    func captureCardPreservesSuggestedTargetAcrossCopyStateUpdates() {
        let target = CaptureSuggestedTarget(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            windowTitle: "api-server",
            capturedAt: .now
        )
        let card = CaptureCard(
            bodyText: "ship it",
            createdAt: .now,
            suggestedTarget: target
        )

        let copied = card.markCopied(at: .now)

        #expect(copied.suggestedTarget == target)
    }

    @Test
    func dailyDigestFormatterBuildsStableTitleAndEscapedHTML() {
        let calendar = Calendar(identifier: .gregorian)
        let createdAt = Date(timeIntervalSince1970: 1_741_507_600)
        let exportDate = Date(timeIntervalSince1970: 1_741_511_200)
        let cards = [
            CaptureCard(
                bodyText: "Fix <redirect> & auth",
                createdAt: createdAt
            ),
        ]

        let title = DailyDigestFormatter.noteTitle(for: exportDate, calendar: calendar)
        let html = DailyDigestFormatter.html(for: cards, date: exportDate, calendar: calendar)

        #expect(title == "Prompt Cue · 2025-03-09")
        #expect(html.contains("Fix &lt;redirect&gt; &amp; auth"))
        #expect(html.contains("Prompt Cue · 2025-03-09"))
    }
}
