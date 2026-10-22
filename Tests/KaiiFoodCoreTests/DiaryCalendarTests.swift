import XCTest
@testable import KaiiFoodCore

final class DiaryCalendarTests: XCTestCase {
    private func calendar(_ zone: String = "Asia/Shanghai") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12,
                      minute: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour, minute: minute))!
    }

    func testWeekBeginsOnMondayAndCrossesYear() throws {
        let calendar = calendar()
        let dates = DiaryCalendar(calendar: calendar)
        let week = dates.week(containing: date(2026, 12, 31, calendar: calendar))
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(Set(week).count, 7)
        XCTAssertEqual(calendar.component(.weekday, from: try XCTUnwrap(week.first)), 2)
        XCTAssertTrue(calendar.isDate(try XCTUnwrap(week.first), inSameDayAs: date(2026, 12, 28, calendar: calendar)))
        XCTAssertTrue(calendar.isDate(try XCTUnwrap(week.last), inSameDayAs: date(2027, 1, 3, calendar: calendar)))
    }

    func testLeapMonthGridIncludesEveryDayOnce() {
        let calendar = calendar()
        let dates = DiaryCalendar(calendar: calendar)
        let february = date(2028, 2, 15, calendar: calendar)
        let days = dates.monthDays(containing: february)
        let grid = dates.monthGrid(containing: february)
        XCTAssertEqual(days.count, 29)
        XCTAssertEqual(grid.count % 7, 0)
        XCTAssertEqual(Set(grid).count, grid.count)
        XCTAssertEqual(grid.filter { calendar.isDate($0, equalTo: february, toGranularity: .month) }, days)
    }

    func testFourWeekMonthHasNoExtraTrailingWeek() {
        let calendar = calendar()
        let dates = DiaryCalendar(calendar: calendar)
        XCTAssertEqual(dates.monthGrid(containing: date(2021, 2, 1, calendar: calendar)).count, 28)
    }

    func testWeekNavigationPreservesLocalTimeAcrossDaylightSaving() {
        let calendar = calendar("America/New_York")
        let dates = DiaryCalendar(calendar: calendar)
        let original = date(2026, 3, 4, hour: 14, minute: 23, calendar: calendar)
        let next = dates.movingWeeks(1, from: original)
        XCTAssertEqual(next, date(2026, 3, 11, hour: 14, minute: 23, calendar: calendar))
        XCTAssertEqual(next.timeIntervalSince(original), 167 * 3600, accuracy: 1)
        XCTAssertEqual(dates.movingWeeks(-1, from: next), original)
    }

    func testChoosingDayPreservesMealDraftTime() {
        let calendar = calendar()
        let dates = DiaryCalendar(calendar: calendar)
        let original = date(2026, 10, 18, hour: 18, minute: 42, calendar: calendar)
        let selection = dates.selecting(date(2026, 8, 31, calendar: calendar), preservingTimeFrom: original)
        XCTAssertEqual(selection, date(2026, 8, 31, hour: 18, minute: 42, calendar: calendar))
        XCTAssertEqual(original, date(2026, 10, 18, hour: 18, minute: 42, calendar: calendar))
    }
}
