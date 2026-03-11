import Foundation
import XCTest
@testable import Prompt_Cue
import PromptCueCore

@MainActor
final class ExecutionMapModelTests: XCTestCase {
    func testRefreshGroupsWorkItemsByRepositoryAndStatus() {
        let loader = StubExecutionMapWorkItemLoader(
            result: .success([
                WorkItem(
                    title: "Prompt queue polish",
                    repoName: "PromptCue",
                    branchName: "feat/polish",
                    status: .open,
                    createdAt: Date(timeIntervalSinceReferenceDate: 100),
                    updatedAt: Date(timeIntervalSinceReferenceDate: 300),
                    createdBy: .user,
                    difficultyHint: .medium,
                    sourceNoteCount: 2
                ),
                WorkItem(
                    title: "Refine export wording",
                    repoName: "PromptCue",
                    branchName: "feat/export",
                    status: .inProgress,
                    createdAt: Date(timeIntervalSinceReferenceDate: 110),
                    updatedAt: Date(timeIntervalSinceReferenceDate: 310),
                    createdBy: .mcpAI,
                    difficultyHint: .small,
                    sourceNoteCount: 1
                ),
                WorkItem(
                    title: "Infra cleanup",
                    repoName: "BacktickWeb",
                    status: .done,
                    createdAt: Date(timeIntervalSinceReferenceDate: 120),
                    updatedAt: Date(timeIntervalSinceReferenceDate: 220),
                    createdBy: .user,
                    sourceNoteCount: 3
                ),
                WorkItem(
                    title: "Loose raw capture",
                    status: .dismissed,
                    createdAt: Date(timeIntervalSinceReferenceDate: 130),
                    updatedAt: Date(timeIntervalSinceReferenceDate: 140),
                    createdBy: .user,
                    sourceNoteCount: 1
                ),
            ])
        )
        let model = ExecutionMapModel(workItemLoader: loader)

        model.refresh()

        XCTAssertNil(model.lastErrorDescription)
        XCTAssertEqual(model.sections.map(\.title), ["BacktickWeb", "PromptCue", "No Repo Context"])
        XCTAssertEqual(model.sections[0].lanes.first(where: { $0.status == .done })?.items.map(\.title), ["Infra cleanup"])
        XCTAssertEqual(model.sections[1].lanes.first(where: { $0.status == .open })?.items.map(\.title), ["Prompt queue polish"])
        XCTAssertEqual(model.sections[1].lanes.first(where: { $0.status == .inProgress })?.items.map(\.title), ["Refine export wording"])
        XCTAssertEqual(model.sections[2].lanes.first(where: { $0.status == .dismissed })?.items.map(\.title), ["Loose raw capture"])
    }

    func testRefreshSortsItemsWithinALaneByUpdatedAtDescending() {
        let loader = StubExecutionMapWorkItemLoader(
            result: .success([
                WorkItem(
                    title: "Older",
                    repoName: "PromptCue",
                    status: .open,
                    createdAt: Date(timeIntervalSinceReferenceDate: 100),
                    updatedAt: Date(timeIntervalSinceReferenceDate: 150),
                    createdBy: .user,
                    sourceNoteCount: 1
                ),
                WorkItem(
                    title: "Newest",
                    repoName: "PromptCue",
                    status: .open,
                    createdAt: Date(timeIntervalSinceReferenceDate: 101),
                    updatedAt: Date(timeIntervalSinceReferenceDate: 250),
                    createdBy: .user,
                    sourceNoteCount: 1
                ),
                WorkItem(
                    title: "Middle",
                    repoName: "PromptCue",
                    status: .open,
                    createdAt: Date(timeIntervalSinceReferenceDate: 102),
                    updatedAt: Date(timeIntervalSinceReferenceDate: 200),
                    createdBy: .user,
                    sourceNoteCount: 1
                ),
            ])
        )
        let model = ExecutionMapModel(workItemLoader: loader)

        model.refresh()

        let openLaneTitles = model.sections[0]
            .lanes
            .first(where: { $0.status == .open })?
            .items
            .map(\.title)

        XCTAssertEqual(openLaneTitles, ["Newest", "Middle", "Older"])
    }

    func testRefreshClearsSectionsAndSurfacesLoadErrors() {
        let loader = StubExecutionMapWorkItemLoader(
            result: .success([
                WorkItem(
                    title: "Keep me",
                    repoName: "PromptCue",
                    status: .open,
                    createdAt: Date(timeIntervalSinceReferenceDate: 100),
                    createdBy: .user,
                    sourceNoteCount: 1
                ),
            ])
        )
        let model = ExecutionMapModel(workItemLoader: loader)
        model.refresh()

        loader.result = .failure(StubError.loadFailed)
        model.refresh()

        XCTAssertEqual(model.sections, [])
        XCTAssertEqual(model.lastErrorDescription, "Couldn't load execution items.")
    }
}

@MainActor
private final class StubExecutionMapWorkItemLoader: ExecutionMapWorkItemLoading {
    var result: Result<[WorkItem], Error>

    init(result: Result<[WorkItem], Error>) {
        self.result = result
    }

    func loadWorkItems() throws -> [WorkItem] {
        try result.get()
    }
}

private enum StubError: Error {
    case loadFailed
}
