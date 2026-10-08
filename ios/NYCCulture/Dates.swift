import Foundation

/// Date helpers. All listing dates are New York calendar days.
enum D {
    static let tz = TimeZone(identifier: "America/New_York") ?? .current

    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.firstWeekday = 2 // weeks start Monday
        return c
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = tz
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    static let iso = formatter("yyyy-MM-dd")
    static let monthDay = formatter("MMM d")
    static let monthDayYear = formatter("MMM d, yyyy")
    static let weekday = formatter("EEE")
    static let monthYear = formatter("MMMM yyyy")
    static let longMonthDay = formatter("MMMM d")

    static func parse(_ s: String?) -> Date? {
        guard let s, s.count >= 10 else { return nil }
        return iso.date(from: String(s.prefix(10)))
    }

    static var today: Date { cal.startOfDay(for: Date()) }

    /// Whole days from today to `d` (negative = in the past).
    static func days(_ d: Date) -> Int {
        cal.dateComponents([.day], from: today, to: cal.startOfDay(for: d)).day ?? 0
    }

    static func weekStart(_ d: Date) -> Date {
        cal.dateInterval(of: .weekOfYear, for: d)?.start ?? cal.startOfDay(for: d)
    }

    static func short(_ d: Date) -> String { monthDay.string(from: d) }
    static func full(_ d: Date) -> String { monthDayYear.string(from: d) }
}
