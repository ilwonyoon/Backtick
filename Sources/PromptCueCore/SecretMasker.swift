import Foundation

public enum SecretMasker {
    private static let maskSymbol = "\u{00B7}" // middle dot ·
    private static let maskCluster = String(repeating: maskSymbol, count: 4)

    public static func mask(
        _ text: String,
        visiblePrefix: Int = 8,
        visibleSuffix: Int = 4
    ) -> String {
        guard text.count > visiblePrefix + visibleSuffix else {
            return text
        }

        let prefixEnd = text.index(text.startIndex, offsetBy: visiblePrefix)
        let suffixStart = text.index(text.endIndex, offsetBy: -visibleSuffix)
        let prefix = text[text.startIndex..<prefixEnd]
        let suffix = text[suffixStart..<text.endIndex]

        return "\(prefix)\(maskCluster)\(suffix)"
    }
}
