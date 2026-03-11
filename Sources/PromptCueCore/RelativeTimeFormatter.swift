import Foundation

public enum RelativeTimeFormatter {
    public static func string(for date: Date, relativeTo now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)

        guard elapsed >= 0 else {
            return "now"
        }

        let seconds = Int(elapsed)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7

        if minutes < 1 {
            return "now"
        }

        if hours < 1 {
            return "\(minutes)m ago"
        }

        if days < 1 {
            return "\(hours)h ago"
        }

        if weeks < 1 {
            return "\(days)d ago"
        }

        return "\(weeks)w ago"
    }
}
