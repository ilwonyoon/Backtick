import Foundation

public enum DailyDigestFormatter {
    public static func noteTitle(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        "Prompt Cue · \(dayFormatter(calendar: calendar).string(from: date))"
    }

    public static func html(
        for cards: [CaptureCard],
        date: Date,
        calendar: Calendar = .current
    ) -> String {
        let title = noteTitle(for: date, calendar: calendar)
        let exportedAt = timestampFormatter(calendar: calendar).string(from: date)
        let bodyItems = cards.map { card in
            let time = timeFormatter(calendar: calendar).string(from: card.createdAt)
            var metadataParts: [String] = []

            if card.screenshotPath != nil {
                metadataParts.append("Screenshot attached")
            }

            let metadata = metadataParts.isEmpty
                ? ""
                : "<div class=\"meta\">\(escapeHTML(metadataParts.joined(separator: " · ")))</div>"

            return """
            <li><div class="time">\(escapeHTML(time))</div><div class="content">\(escapeHTML(card.bodyText))</div>\(metadata)</li>
            """
        }
        .joined()

        return """
        <html><head><meta charset="utf-8"><style>body{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text',sans-serif;margin:24px;color:#111;}h1{font-size:24px;line-height:1.2;margin:0 0 8px;}p{margin:0 0 18px;color:#666;font-size:13px;}ul{margin:0;padding:0;list-style:none;}li{padding:12px 0;border-bottom:1px solid #e5e5e5;}.time{font-size:12px;color:#666;margin-bottom:4px;}.content{font-size:15px;line-height:1.45;white-space:pre-wrap;}.meta{font-size:12px;color:#0a84ff;margin-top:6px;}</style></head><body><h1>\(escapeHTML(title))</h1><p>Exported \(escapeHTML(exportedAt)) · \(cards.count) card\(cards.count == 1 ? "" : "s")</p><ul>\(bodyItems)</ul></body></html>
        """
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func dayFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func timeFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private static func timestampFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}
