import Foundation
import PromptCueCore
import SwiftUI

@MainActor
protocol ExecutionMapWorkItemLoading: AnyObject {
    func loadWorkItems() throws -> [WorkItem]
}

extension WorkItemStore: ExecutionMapWorkItemLoading {}

struct ExecutionMapLane: Identifiable, Equatable {
    let status: WorkItemStatus
    let items: [WorkItem]

    var id: String {
        status.rawValue
    }
}

struct ExecutionMapSection: Identifiable, Equatable {
    let repoName: String?
    let title: String
    let lanes: [ExecutionMapLane]

    var id: String {
        repoName ?? "__no_repo_context__"
    }

    var workItemCount: Int {
        lanes.reduce(0) { $0 + $1.items.count }
    }
}

@MainActor
final class ExecutionMapModel: ObservableObject {
    @Published private(set) var sections: [ExecutionMapSection] = []
    @Published private(set) var lastErrorDescription: String?

    private let workItemLoader: ExecutionMapWorkItemLoading

    init(workItemLoader: ExecutionMapWorkItemLoading) {
        self.workItemLoader = workItemLoader
    }

    func refresh() {
        do {
            sections = Self.buildSections(from: try workItemLoader.loadWorkItems())
            lastErrorDescription = nil
        } catch {
            sections = []
            lastErrorDescription = "Couldn't load execution items."
            NSLog("ExecutionMapModel refresh failed: %@", error.localizedDescription)
        }
    }

    private static func buildSections(from workItems: [WorkItem]) -> [ExecutionMapSection] {
        let groupedByRepo = Dictionary(grouping: workItems, by: { normalizedRepoName(from: $0) })

        return groupedByRepo
            .map { repoName, groupedItems in
                let lanes = laneOrder.map { status in
                    ExecutionMapLane(
                        status: status,
                        items: groupedItems
                            .filter { $0.status == status }
                            .sorted(by: sortWorkItems)
                    )
                }

                return ExecutionMapSection(
                    repoName: repoName,
                    title: repoName ?? "No Repo Context",
                    lanes: lanes
                )
            }
            .sorted(by: sortSections)
    }

    private static func normalizedRepoName(from workItem: WorkItem) -> String? {
        guard let repoName = workItem.repoName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !repoName.isEmpty else {
            return nil
        }

        return repoName
    }

    private static func sortSections(lhs: ExecutionMapSection, rhs: ExecutionMapSection) -> Bool {
        switch (lhs.repoName, rhs.repoName) {
        case let (left?, right?):
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func sortWorkItems(lhs: WorkItem, rhs: WorkItem) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static let laneOrder: [WorkItemStatus] = [
        .open,
        .inProgress,
        .done,
        .dismissed,
    ]
}
