import Foundation

public enum CaptureReviewMode: String, CaseIterable, Identifiable, Sendable {
    case stack

    public var id: String {
        rawValue
    }

    public var title: String {
        "Stack"
    }
}
