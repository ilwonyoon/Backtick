import XCTest
@testable import PromptCueCore

final class TimedIDSuppressorTests: XCTestCase {
    func testInsertedIDIsSuppressed() {
        var suppressor = TimedIDSuppressor(ttl: 30)
        let id = UUID()
        let now = Date()
        suppressor.insert(id, at: now)
        XCTAssertTrue(suppressor.isSuppressed(id, at: now))
    }

    func testUnknownIDIsNotSuppressed() {
        let suppressor = TimedIDSuppressor(ttl: 30)
        XCTAssertFalse(suppressor.isSuppressed(UUID()))
    }

    func testIDExpiresAfterTTL() {
        var suppressor = TimedIDSuppressor(ttl: 30)
        let id = UUID()
        let now = Date()
        suppressor.insert(id, at: now)
        let future = now.addingTimeInterval(31)
        XCTAssertFalse(suppressor.isSuppressed(id, at: future))
    }

    func testIDNotExpiredBeforeTTL() {
        var suppressor = TimedIDSuppressor(ttl: 30)
        let id = UUID()
        let now = Date()
        suppressor.insert(id, at: now)
        let future = now.addingTimeInterval(29)
        XCTAssertTrue(suppressor.isSuppressed(id, at: future))
    }

    func testPruneRemovesExpiredEntries() {
        var suppressor = TimedIDSuppressor(ttl: 10)
        let old = UUID()
        let recent = UUID()
        let now = Date()
        suppressor.insert(old, at: now.addingTimeInterval(-15))
        suppressor.insert(recent, at: now.addingTimeInterval(-5))
        suppressor.prune(before: now)
        XCTAssertFalse(suppressor.isSuppressed(old, at: now))
        XCTAssertTrue(suppressor.isSuppressed(recent, at: now))
    }

    func testMultipleIDsIndependent() {
        var suppressor = TimedIDSuppressor(ttl: 30)
        let id1 = UUID()
        let id2 = UUID()
        let now = Date()
        suppressor.insert(id1, at: now)
        XCTAssertTrue(suppressor.isSuppressed(id1, at: now))
        XCTAssertFalse(suppressor.isSuppressed(id2, at: now))
    }
}
