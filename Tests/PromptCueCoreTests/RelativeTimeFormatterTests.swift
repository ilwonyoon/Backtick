import XCTest
@testable import PromptCueCore

final class RelativeTimeFormatterTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 100_000)

    func testJustNow() {
        let date = now.addingTimeInterval(-10)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date, relativeTo: now), "now")
    }

    func testZeroSecondsAgo() {
        XCTAssertEqual(RelativeTimeFormatter.string(for: now, relativeTo: now), "now")
    }

    func testThreeMinutesAgo() {
        let date = now.addingTimeInterval(-180)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date, relativeTo: now), "3m ago")
    }

    func testFiftyNineMinutesAgo() {
        let date = now.addingTimeInterval(-59 * 60)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date, relativeTo: now), "59m ago")
    }

    func testOneHourAgo() {
        let date = now.addingTimeInterval(-3600)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date, relativeTo: now), "1h ago")
    }

    func testNinetyMinutesAgo() {
        let date = now.addingTimeInterval(-90 * 60)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date, relativeTo: now), "1h ago")
    }

    func testTwentyFiveHoursAgo() {
        let date = now.addingTimeInterval(-25 * 3600)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date, relativeTo: now), "1d ago")
    }

    func testSixDaysAgo() {
        let date = now.addingTimeInterval(-6 * 86400)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date, relativeTo: now), "6d ago")
    }

    func testSevenDaysAgo() {
        let date = now.addingTimeInterval(-7 * 86400)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date, relativeTo: now), "1w ago")
    }

    func testFutureDateReturnsNow() {
        let future = now.addingTimeInterval(300)
        XCTAssertEqual(RelativeTimeFormatter.string(for: future, relativeTo: now), "now")
    }
}
