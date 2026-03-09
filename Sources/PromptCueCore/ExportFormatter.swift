import Foundation

public struct ExportSuffix: Equatable, Sendable {
    public static let off = ExportSuffix(nil)

    public let rawValue: String?

    public init(_ rawValue: String?) {
        self.rawValue = rawValue
    }

    var normalizedValue: String? {
        guard let rawValue else {
            return nil
        }

        let normalizedLineEndings = rawValue
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedLineEndings.isEmpty == false else {
            return nil
        }

        return normalizedLineEndings
    }
}

public enum ExportFormatter {
    public static func string(for cards: [CaptureCard]) -> String {
        string(for: cards, suffix: .off)
    }

    public static func string(for cards: [CaptureCard], suffix: ExportSuffix) -> String {
        let basePayload = cards
            .map { "\u{2022} \($0.text)" }
            .joined(separator: "\n")

        guard let normalizedSuffix = suffix.normalizedValue, basePayload.isEmpty == false else {
            return basePayload
        }

        return basePayload + "\n\n" + normalizedSuffix
    }

    public static func string(for cards: [CaptureCard], suffix: String?) -> String {
        string(for: cards, suffix: ExportSuffix(suffix))
    }
}
