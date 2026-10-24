import Foundation
import Observation

@Observable
final class DateFilterStore {
    var startDate: Date
    var endDate: Date

    init(referenceDate: Date = .now) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        self.startDate = start
        self.endDate = end
    }

    var filter: DateRangeFilter {
        DateRangeFilter(start: startDate, end: endDate)
    }

    var label: String {
        DateDisplay.rangeLabel(start: startDate, end: endDate)
    }
}

enum DateDisplay {
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    static func rangeLabel(start: Date, end: Date) -> String {
        "\(day(start)) 至 \(day(end))"
    }

    static func dayKey(from time: String) -> String {
        let raw = time.split(separator: " ").first.map(String.init) ?? time
        if let date = DateRangeFilter.date(from: time) {
            return day(date)
        }
        return raw
    }
}
