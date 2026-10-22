import Foundation

public struct DiaryCalendar {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        var calendar = calendar
        calendar.firstWeekday = 2
        self.calendar = calendar
    }

    public func week(containing date: Date) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        guard let first = calendar.date(byAdding: .day, value: -offset, to: day) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    public func monthDays(containing date: Date) -> [Date] {
        guard let first = calendar.dateInterval(of: .month, for: date)?.start,
              let days = calendar.range(of: .day, in: .month, for: date) else { return [] }
        return days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    public func monthGrid(containing date: Date) -> [Date] {
        let days = monthDays(containing: date)
        guard let firstDay = days.first, let lastDay = days.last,
              let first = week(containing: firstDay).first,
              let last = week(containing: lastDay).last,
              let count = calendar.dateComponents([.day], from: first, to: last).day else { return [] }
        return (0...count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    public func movingWeeks(_ offset: Int, from date: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: offset, to: date) ?? date
    }

    public func selecting(_ day: Date, preservingTimeFrom date: Date) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second], from: date)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0,
                             second: time.second ?? 0, of: day) ?? day
    }
}
