import Foundation

enum MCPPromptRenderer {
    static func render(
        template: MCPPromptTemplate,
        arguments: [String: String]
    ) throws -> String {
        let requiredNames = Set(
            template.arguments
                .filter(\.required)
                .map(\.name)
        )
        let knownNames = Set(template.arguments.map(\.name))

        for name in requiredNames {
            guard let value = arguments[name],
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BacktickMCPToolError(message: "Required argument '\(name)' is missing or empty")
            }
        }

        let templateBody = template.bodyTemplate
        let placeholderPattern = #"\{([A-Za-z0-9_]+)\}"#
        let placeholderRegex = try NSRegularExpression(pattern: placeholderPattern)
        let placeholderMatches = placeholderRegex.matches(
            in: templateBody,
            range: NSRange(templateBody.startIndex..., in: templateBody)
        )

        var result = templateBody
        for match in placeholderMatches.reversed() {
            guard let placeholderRange = Range(match.range(at: 0), in: result),
                  let nameRange = Range(match.range(at: 1), in: templateBody) else {
                continue
            }

            let name = String(templateBody[nameRange])
            guard knownNames.contains(name) else {
                continue
            }

            let replacement = arguments[name] ?? "(not specified)"
            result.replaceSubrange(placeholderRange, with: replacement)
        }

        return result
    }
}
