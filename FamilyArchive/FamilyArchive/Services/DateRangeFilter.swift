import Foundation

struct DateRangeFilter: Equatable {
    var start: Date
    var end: Date

    init(start: Date, end: Date) {
        if start <= end {
            self.start = start
            self.end = end
        } else {
            self.start = end
            self.end = start
        }
    }

    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: start)
        guard let endExclusive = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: end)
        ) else { return false }
        return date >= startOfStart && date < endExclusive
    }

    /// Unknown or unparseable HAR dates are kept visible rather than hidden.
    func matches(timeString: String) -> Bool {
        guard let date = DateRangeFilter.date(from: timeString) else { return true }
        return contains(date)
    }

    static func date(from value: String) -> Date? {
        let formats = [
            "yyyy年MM月dd日 HH:mm",
            "yyyy年MM月dd日",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
