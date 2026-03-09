import Foundation

public struct CaptureCard: Codable, Identifiable, Equatable, Sendable {
    public static let ttl: TimeInterval = PromptCueConstants.defaultTTL

    public let id: UUID
    public let bodyText: String
    public let suggestedTarget: CaptureSuggestedTarget?
    public let createdAt: Date
    public let screenshotPath: String?
    public let lastCopiedAt: Date?
    public let sortOrder: Double

    public init(
        id: UUID = UUID(),
        bodyText: String,
        createdAt: Date,
        suggestedTarget: CaptureSuggestedTarget? = nil,
        screenshotPath: String? = nil,
        lastCopiedAt: Date? = nil,
        sortOrder: Double? = nil
    ) {
        self.id = id
        self.bodyText = bodyText
        self.suggestedTarget = suggestedTarget
        self.createdAt = createdAt
        self.screenshotPath = screenshotPath
        self.lastCopiedAt = lastCopiedAt
        self.sortOrder = sortOrder ?? createdAt.timeIntervalSinceReferenceDate
    }

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date,
        suggestedTarget: CaptureSuggestedTarget? = nil,
        screenshotPath: String? = nil,
        lastCopiedAt: Date? = nil,
        sortOrder: Double? = nil
    ) {
        self.init(
            id: id,
            bodyText: text,
            createdAt: createdAt,
            suggestedTarget: suggestedTarget,
            screenshotPath: screenshotPath,
            lastCopiedAt: lastCopiedAt,
            sortOrder: sortOrder
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bodyText
        case text
        case suggestedTarget
        case createdAt
        case screenshotPath
        case lastCopiedAt
        case sortOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let decodedBodyText = try container.decodeIfPresent(String.self, forKey: .bodyText) {
            bodyText = decodedBodyText
        } else {
            bodyText = try container.decode(String.self, forKey: .text)
        }
        suggestedTarget = try container.decodeIfPresent(CaptureSuggestedTarget.self, forKey: .suggestedTarget)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        screenshotPath = try container.decodeIfPresent(String.self, forKey: .screenshotPath)
        lastCopiedAt = try container.decodeIfPresent(Date.self, forKey: .lastCopiedAt)
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder)
            ?? createdAt.timeIntervalSinceReferenceDate
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bodyText, forKey: .bodyText)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(suggestedTarget, forKey: .suggestedTarget)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(screenshotPath, forKey: .screenshotPath)
        try container.encodeIfPresent(lastCopiedAt, forKey: .lastCopiedAt)
        try container.encode(sortOrder, forKey: .sortOrder)
    }

    public var text: String {
        bodyText
    }

    public var isCopied: Bool {
        lastCopiedAt != nil
    }

    public var screenshotURL: URL? {
        guard let screenshotPath else {
            return nil
        }
        return URL(fileURLWithPath: screenshotPath)
    }

    public func markCopied(at date: Date = Date()) -> CaptureCard {
        CaptureCard(
            id: id,
            bodyText: bodyText,
            createdAt: createdAt,
            suggestedTarget: suggestedTarget,
            screenshotPath: screenshotPath,
            lastCopiedAt: date,
            sortOrder: sortOrder
        )
    }

    public func updatingSortOrder(_ sortOrder: Double) -> CaptureCard {
        CaptureCard(
            id: id,
            bodyText: bodyText,
            createdAt: createdAt,
            suggestedTarget: suggestedTarget,
            screenshotPath: screenshotPath,
            lastCopiedAt: lastCopiedAt,
            sortOrder: sortOrder
        )
    }

    public func updatingSuggestedTarget(_ suggestedTarget: CaptureSuggestedTarget?) -> CaptureCard {
        CaptureCard(
            id: id,
            bodyText: bodyText,
            createdAt: createdAt,
            suggestedTarget: suggestedTarget,
            screenshotPath: screenshotPath,
            lastCopiedAt: lastCopiedAt,
            sortOrder: sortOrder
        )
    }

    public func isExpired(
        relativeTo date: Date = Date(),
        ttl: TimeInterval = CaptureCard.ttl
    ) -> Bool {
        createdAt.addingTimeInterval(ttl) < date
    }
}
