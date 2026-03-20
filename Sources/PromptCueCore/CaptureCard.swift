import Foundation

public struct CaptureCard: Codable, Identifiable, Equatable, Sendable {
    public static let ttl: TimeInterval = PromptCueConstants.defaultTTL

    public let id: UUID
    public let text: String
    public let tags: [CaptureTag]
    public let createdAt: Date
    public let screenshotPath: String?
    public let lastCopiedAt: Date?
    public let sortOrder: Double
    public let isPinned: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        tags: [CaptureTag] = [],
        createdAt: Date,
        screenshotPath: String? = nil,
        lastCopiedAt: Date? = nil,
        sortOrder: Double? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text

        let extractedTags = CaptureTagText.extractCanonicalInlineTags(in: text).tags
        self.tags = CaptureTag.deduplicatePreservingOrder(extractedTags + tags)

        self.createdAt = createdAt
        self.screenshotPath = screenshotPath
        self.lastCopiedAt = lastCopiedAt
        self.sortOrder = sortOrder ?? createdAt.timeIntervalSinceReferenceDate
        self.isPinned = isPinned
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case tags
        case createdAt
        case screenshotPath
        case lastCopiedAt
        case sortOrder
        case isPinned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)

        let decodedTags = CaptureTag.deduplicatePreservingOrder(
            try container.decodeIfPresent([CaptureTag].self, forKey: .tags) ?? []
        )
        let extractedTags = CaptureTagText.extractCanonicalInlineTags(in: text).tags
        tags = CaptureTag.deduplicatePreservingOrder(extractedTags + decodedTags)

        createdAt = try container.decode(Date.self, forKey: .createdAt)
        screenshotPath = try container.decodeIfPresent(String.self, forKey: .screenshotPath)
        lastCopiedAt = try container.decodeIfPresent(Date.self, forKey: .lastCopiedAt)
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder)
            ?? createdAt.timeIntervalSinceReferenceDate
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(tags, forKey: .tags)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(screenshotPath, forKey: .screenshotPath)
        try container.encodeIfPresent(lastCopiedAt, forKey: .lastCopiedAt)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(isPinned, forKey: .isPinned)
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

    public var visibleBodyText: String {
        text
    }

    public var visibleInlineText: String {
        if text.contains("#") || tags.isEmpty {
            return text
        }

        return CaptureTagText.legacyInlineDisplayText(tags: tags, bodyText: text)
    }

    public var visibleInlineTagRanges: [NSRange] {
        let ranges = CaptureTagText.inlineDisplayTagRanges(tags: tags, bodyText: text)
        if !ranges.isEmpty || text.contains("#") || tags.isEmpty {
            return ranges
        }

        return CaptureTagText.legacyInlineDisplayTagRanges(tags: tags, bodyText: text)
    }

    public func markCopied(at date: Date = Date()) -> CaptureCard {
        CaptureCard(
            id: id,
            text: text,
            tags: tags,
            createdAt: createdAt,
            screenshotPath: screenshotPath,
            lastCopiedAt: date,
            sortOrder: sortOrder,
            isPinned: isPinned
        )
    }

    public func updatingSortOrder(_ sortOrder: Double) -> CaptureCard {
        CaptureCard(
            id: id,
            text: text,
            tags: tags,
            createdAt: createdAt,
            screenshotPath: screenshotPath,
            lastCopiedAt: lastCopiedAt,
            sortOrder: sortOrder,
            isPinned: isPinned
        )
    }

    public func updatingContent(
        text: String,
        tags: [CaptureTag],
        screenshotPath: String?
    ) -> CaptureCard {
        CaptureCard(
            id: id,
            text: text,
            tags: tags,
            createdAt: createdAt,
            screenshotPath: screenshotPath,
            lastCopiedAt: lastCopiedAt,
            sortOrder: sortOrder,
            isPinned: isPinned
        )
    }

    public func togglePinned() -> CaptureCard {
        CaptureCard(
            id: id,
            text: text,
            tags: tags,
            createdAt: createdAt,
            screenshotPath: screenshotPath,
            lastCopiedAt: lastCopiedAt,
            sortOrder: sortOrder,
            isPinned: !isPinned
        )
    }

    public func isExpired(
        relativeTo date: Date = Date(),
        ttl: TimeInterval = CaptureCard.ttl
    ) -> Bool {
        if isPinned { return false }
        return createdAt.addingTimeInterval(ttl) < date
    }

    public func ttlProgressRemaining(
        relativeTo date: Date = Date(),
        ttl: TimeInterval = CaptureCard.ttl
    ) -> Double {
        guard ttl > 0 else {
            return 0
        }

        let remaining = createdAt.addingTimeInterval(ttl).timeIntervalSince(date)
        let progress = remaining / ttl
        return min(max(progress, 0), 1)
    }

    public func ttlRemainingMinutes(
        relativeTo date: Date = Date(),
        ttl: TimeInterval = CaptureCard.ttl
    ) -> Int? {
        guard ttl > 0, !isPinned else {
            return nil
        }

        let remainingSeconds = createdAt.addingTimeInterval(ttl).timeIntervalSince(date)
        guard remainingSeconds > 0, remainingSeconds < 3600 else {
            return nil
        }

        return max(Int(ceil(remainingSeconds / 60)), 1)
    }
}
