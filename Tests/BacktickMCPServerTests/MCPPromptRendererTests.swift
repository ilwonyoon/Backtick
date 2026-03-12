import XCTest
@testable import BacktickMCPServer

final class MCPPromptRendererTests: XCTestCase {
    func testRenderReplacesKnownArguments() throws {
        let template = MCPPromptTemplate(
            name: "sample",
            description: "sample",
            arguments: [
                MCPPromptArgument(name: "name", description: "name", required: true),
                MCPPromptArgument(name: "branch", description: "branch", required: false),
            ],
            bodyTemplate: "Hello {name} on {branch}"
        )

        let rendered = try MCPPromptRenderer.render(
            template: template,
            arguments: [
                "name": "Backtick",
                "branch": "main",
            ]
        )

        XCTAssertEqual(rendered, "Hello Backtick on main")
    }

    func testRenderUsesFallbackForMissingOptionalArgument() throws {
        let template = MCPPromptTemplate(
            name: "sample",
            description: "sample",
            arguments: [
                MCPPromptArgument(name: "name", description: "name", required: true),
                MCPPromptArgument(name: "branch", description: "branch", required: false),
            ],
            bodyTemplate: "Hello {name} on {branch}"
        )

        let rendered = try MCPPromptRenderer.render(
            template: template,
            arguments: ["name": "Backtick"]
        )

        XCTAssertEqual(rendered, "Hello Backtick on (not specified)")
    }

    func testRenderThrowsWhenRequiredArgumentMissing() {
        let template = MCPPromptTemplate(
            name: "sample",
            description: "sample",
            arguments: [
                MCPPromptArgument(name: "name", description: "name", required: true),
            ],
            bodyTemplate: "Hello {name}"
        )

        XCTAssertThrowsError(
            try MCPPromptRenderer.render(template: template, arguments: [:])
        )
    }

    func testRenderLeavesUnknownPlaceholderUntouched() throws {
        let template = MCPPromptTemplate(
            name: "sample",
            description: "sample",
            arguments: [
                MCPPromptArgument(name: "name", description: "name", required: true),
            ],
            bodyTemplate: "Hello {name} {unknown}"
        )

        let rendered = try MCPPromptRenderer.render(
            template: template,
            arguments: ["name": "Backtick"]
        )

        XCTAssertEqual(rendered, "Hello Backtick {unknown}")
    }
}
