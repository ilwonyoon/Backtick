import Foundation

public enum ContentType: String, Sendable, Codable, CaseIterable {
    case path
    case link
    case secret
    case plain
}

public struct DetectedSpan: Equatable, Sendable {
    public let range: Range<String.Index>
    public let matchedText: String
    public let type: ContentType

    public init(range: Range<String.Index>, matchedText: String, type: ContentType) {
        self.range = range
        self.matchedText = matchedText
        self.type = type
    }
}

public struct ContentClassification: Equatable, Sendable {
    public let primaryType: ContentType
    public let span: DetectedSpan?

    public init(primaryType: ContentType, span: DetectedSpan?) {
        self.primaryType = primaryType
        self.span = span
    }

    public static let plain = ContentClassification(
        primaryType: .plain,
        span: nil
    )
}
