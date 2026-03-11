import XCTest
@testable import PromptCueCore

final class SecretMaskerTests: XCTestCase {

    func testStandardMasking() {
        let result = SecretMasker.mask("sk-ant-abc123def456xyz789end")
        XCTAssertTrue(result.hasPrefix("sk-ant-a"))
        XCTAssertTrue(result.hasSuffix("9end"))
        XCTAssertTrue(result.contains("····"))
    }

    func testShortStringReturnedAsIs() {
        let result = SecretMasker.mask("short")
        XCTAssertEqual(result, "short")
    }

    func testExactBoundaryLengthReturnedAsIs() {
        // visiblePrefix(8) + visibleSuffix(4) = 12
        let text = "123456789012"
        let result = SecretMasker.mask(text)
        XCTAssertEqual(result, text)
    }

    func testOneCharLongerThanBoundaryIsMasked() {
        let text = "1234567890123" // 13 chars
        let result = SecretMasker.mask(text)
        XCTAssertTrue(result.contains("····"))
        XCTAssertEqual(result.count, 8 + 4 + 4) // prefix + mask + suffix
    }

    func testEmptyStringReturnsEmpty() {
        let result = SecretMasker.mask("")
        XCTAssertEqual(result, "")
    }

    func testCustomPrefixSuffix() {
        let result = SecretMasker.mask("sk-ant-abc123def456xyz", visiblePrefix: 4, visibleSuffix: 3)
        XCTAssertTrue(result.hasPrefix("sk-a"))
        XCTAssertTrue(result.hasSuffix("xyz"))
        XCTAssertTrue(result.contains("····"))
    }
}
