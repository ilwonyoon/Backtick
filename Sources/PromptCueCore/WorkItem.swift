import Foundation

public enum WorkItemStatus: String, Codable, CaseIterable, Sendable {
    case open
    case inProgress = "in_progress"
    case done
    case dismissed
}

public enum WorkItemCreatedBy: String, Codable, Sendable {
    case user
    case mcpAI = "mcp_ai"
}

public enum WorkItemDifficultyHint: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large
}

public struct WorkItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let summary: String?
    public let repoName: String?
    public let branchName: String?
    public let status: WorkItemStatus
    public let createdAt: Date
    public let updatedAt: Date
    public let createdBy: WorkItemCreatedBy
    public let difficultyHint: WorkItemDifficultyHint?
    public let sourceNoteCount: Int

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        repoName: String? = nil,
        branchName: String? = nil,
        status: WorkItemStatus = .open,
        createdAt: Date,
        updatedAt: Date? = nil,
        createdBy: WorkItemCreatedBy,
        difficultyHint: WorkItemDifficultyHint? = nil,
        sourceNoteCount: Int
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = Self.sanitizedOptional(summary)
        self.repoName = Self.sanitizedOptional(repoName)
        self.branchName = Self.sanitizedOptional(branchName)
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.createdBy = createdBy
        self.difficultyHint = difficultyHint
        self.sourceNoteCount = max(0, sourceNoteCount)
    }

    public var isResolved: Bool {
        switch status {
        case .done, .dismissed:
            return true
        case .open, .inProgress:
            return false
        }
    }

    public func updatingStatus(
        _ status: WorkItemStatus,
        updatedAt: Date = Date()
    ) -> WorkItem {
        WorkItem(
            id: id,
            title: title,
            summary: summary,
            repoName: repoName,
            branchName: branchName,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdBy: createdBy,
            difficultyHint: difficultyHint,
            sourceNoteCount: sourceNoteCount
        )
    }

    private static func sanitizedOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}
