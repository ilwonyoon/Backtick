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

        var result = template.bodyTemplate
        for argument in template.arguments {
            let placeholder = "{\(argument.name)}"
            let replacement = arguments[argument.name] ?? "(not specified)"
            result = result.replacingOccurrences(of: placeholder, with: replacement)
        }

        return result
    }
}
