import Foundation

public enum CaptureCardGrouping {
    public static func stackCards(_ cards: [CaptureCard]) -> [CaptureCard] {
        cards.sorted(by: compareByCreatedAtDescending)
    }

    private static func compareByCreatedAtDescending(_ lhs: CaptureCard, _ rhs: CaptureCard) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder > rhs.sortOrder
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
