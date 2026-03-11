import Foundation

public enum CopyEventVia: String, Codable, CaseIterable, Sendable {
    case clipboard
    case workItemExport = "work_item_export"
    case bundleExport = "bundle_export"
    case agentRun = "agent_run"
}

public enum CopyEventActor: String, Codable, CaseIterable, Sendable {
    case user
    case mcp
}

public struct CopyEvent: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let noteID: UUID
    public let sessionID: String?
    public let copiedAt: Date
    public let copiedVia: CopyEventVia
    public let copiedBy: CopyEventActor

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        sessionID: String? = nil,
        copiedAt: Date,
        copiedVia: CopyEventVia,
        copiedBy: CopyEventActor
    ) {
        self.id = id
        self.noteID = noteID
        self.sessionID = Self.sanitizedOptional(sessionID)
        self.copiedAt = copiedAt
        self.copiedVia = copiedVia
        self.copiedBy = copiedBy
    }

    private static func sanitizedOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}
