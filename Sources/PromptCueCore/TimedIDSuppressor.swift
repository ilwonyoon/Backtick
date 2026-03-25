import Foundation

public struct TimedIDSuppressor: Sendable {
    private var timestamps: [UUID: Date]
    private let ttl: TimeInterval

    public init(ttl: TimeInterval = 30) {
        self.timestamps = [:]
        self.ttl = ttl
    }

    public mutating func insert(_ id: UUID, at date: Date = Date()) {
        prune(before: date)
        timestamps[id] = date
    }

    public func isSuppressed(_ id: UUID, at date: Date = Date()) -> Bool {
        guard let timestamp = timestamps[id] else { return false }
        return date.timeIntervalSince(timestamp) < ttl
    }

    public mutating func prune(before date: Date = Date()) {
        let cutoff = date.addingTimeInterval(-ttl)
        timestamps = timestamps.filter { $0.value > cutoff }
    }
}
