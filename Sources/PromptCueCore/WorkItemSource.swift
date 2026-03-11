import Foundation

public enum WorkItemSourceRelationType: String, Codable, CaseIterable, Sendable {
    case primary
    case supporting
    case duplicate
}

public struct WorkItemSource: Codable, Equatable, Sendable {
    public let workItemID: UUID
    public let noteID: UUID
    public let relationType: WorkItemSourceRelationType

    public init(
        workItemID: UUID,
        noteID: UUID,
        relationType: WorkItemSourceRelationType = .supporting
    ) {
        self.workItemID = workItemID
        self.noteID = noteID
        self.relationType = relationType
    }
}
