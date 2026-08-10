import XCTest
@testable import SportsHub

final class MatchesDateRailTests: XCTestCase {
    func testRailProducesFiveLocalCalendarDaysAcrossDST() {
        let calendar = calendar(timeZone: "America/Los_Angeles")
        let center = date(2026, 3, 8, hour: 12, calendar: calendar)
        let rail = MatchesDateRail(
            centerDate: center,
            selectedDate: center,
            calendar: calendar
        )

        XCTAssertEqual(
            rail.dates.map { dayString($0, calendar: calendar) },
            ["2026-03-06", "2026-03-07", "2026-03-08", "2026-03-09", "2026-03-10"]
        )
        XCTAssertEqual(rail.dates.count, 5)
        XCTAssertTrue(calendar.isDate(rail.selectedDate, inSameDayAs: center))
    }

    func testRailSelectionKeepsCenterAndNormalizesTheSelectedDay() {
        let calendar = calendar(timeZone: "Asia/Singapore")
        let center = date(2026, 8, 7, hour: 13, calendar: calendar)
        let rail = MatchesDateRail(
            centerDate: center,
            selectedDate: center,
            calendar: calendar
        )
        let selected = rail.selecting(rail.date(at: 2), recenter: false)

        XCTAssertTrue(calendar.isDate(selected.centerDate, inSameDayAs: center))
        XCTAssertEqual(dayString(selected.selectedDate, calendar: calendar), "2026-08-09")
        XCTAssertEqual(
            selected.selectedDate,
            calendar.startOfDay(for: selected.selectedDate)
        )
    }

    func testCalendarSelectionRecentersTheFiveDayRail() {
        let calendar = calendar(timeZone: "Asia/Riyadh")
        let initial = date(2026, 1, 1, hour: 12, calendar: calendar)
        let arbitrary = date(2027, 2, 20, hour: 21, calendar: calendar)
        let selected = MatchesDateRail(
            centerDate: initial,
            selectedDate: initial,
            calendar: calendar
        ).selecting(arbitrary, recenter: true)

        XCTAssertEqual(dayString(selected.centerDate, calendar: calendar), "2027-02-20")
        XCTAssertEqual(dayString(selected.selectedDate, calendar: calendar), "2027-02-20")
        XCTAssertEqual(
            selected.dates.map { dayString($0, calendar: calendar) },
            ["2027-02-18", "2027-02-19", "2027-02-20", "2027-02-21", "2027-02-22"]
        )
    }

    func testRelativeLabelsUseActualReferenceDayInsteadOfRailOffset() {
        let calendar = calendar(timeZone: "Asia/Singapore")
        let today = date(2026, 8, 7, hour: 18, calendar: calendar)
        let rail = MatchesDateRail(
            centerDate: date(2027, 1, 10, calendar: calendar),
            selectedDate: date(2027, 1, 10, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(
            rail.relativeDay(for: date(2026, 8, 6, calendar: calendar), today: today),
            .yesterday
        )
        XCTAssertEqual(rail.relativeDay(for: today, today: today), .today)
        XCTAssertEqual(
            rail.relativeDay(for: date(2026, 8, 8, calendar: calendar), today: today),
            .tomorrow
        )
        XCTAssertNil(
            rail.relativeDay(for: date(2027, 1, 10, calendar: calendar), today: today)
        )
    }

    private func calendar(timeZone identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        guard let timeZone = TimeZone(identifier: identifier) else {
            XCTFail("Missing test time zone: \(identifier)")
            return calendar
        }
        calendar.timeZone = timeZone
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        guard let date = components.date else {
            XCTFail("Unable to create test date")
            return .distantPast
        }
        return date
    }

    private func dayString(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
