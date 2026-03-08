import Foundation

public struct ScreenshotAttachment: Equatable, Codable, Sendable {
    public let path: String
    public let modifiedAt: Date?
    public let fileSize: Int?

    public init(path: String, modifiedAt: Date? = nil, fileSize: Int? = nil) {
        self.path = path
        self.modifiedAt = modifiedAt
        self.fileSize = fileSize
    }

    public var identityKey: String {
        let timestamp = modifiedAt?.timeIntervalSinceReferenceDate ?? 0
        let size = fileSize ?? 0
        return "\(path)#\(timestamp)#\(size)"
    }
}
