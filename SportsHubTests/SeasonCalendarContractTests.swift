import XCTest
@testable import SportsHub

final class SeasonCalendarContractTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testUpcomingScopeAndKindFilterPreserveProviderOrder() throws {
        let snapshot = validSnapshot()
        let upcoming = try SeasonCalendarPresentation(
            snapshot: snapshot,
            scope: .upcoming,
            selectedKind: nil,
            referenceDate: date(day: 10),
            calendar: calendar
        )
        let draws = try SeasonCalendarPresentation(
            snapshot: snapshot,
            scope: .fullSeason,
            selectedKind: .draw,
            referenceDate: date(day: 10),
            calendar: calendar
        )

        XCTAssertEqual(upcoming.visibleEvents.map(\.id), ["draw", "window", "break"])
        XCTAssertEqual(draws.visibleEvents.map(\.id), ["draw"])
        XCTAssertEqual(upcoming.availableKinds, [
            .competitionMilestone,
            .draw,
            .transferWindow,
            .internationalBreak
        ])
    }

    func testOngoingRangeRemainsUpcomingAndMonthsStayChronological() throws {
        let snapshot = validSnapshot()
        let presentation = try SeasonCalendarPresentation(
            snapshot: snapshot,
            scope: .upcoming,
            selectedKind: nil,
            referenceDate: date(day: 24),
            calendar: calendar
        )

        XCTAssertEqual(presentation.visibleEvents.map(\.id), ["window", "break"])
        XCTAssertEqual(presentation.monthGroups.flatMap(\.events).map(\.id), ["window", "break"])
        XCTAssertEqual(presentation.nextUpcomingEvent?.id, "window")
    }

    func testRejectsInvalidRangeDuplicateIDsAndOrder() {
        let base = validSnapshot()
        XCTAssertThrowsError(try presentation(SeasonCalendarSnapshot(
            rangeStart: base.rangeEnd,
            rangeEnd: base.rangeStart,
            updatedAt: base.updatedAt,
            sourceName: base.sourceName,
            events: base.events
        ))) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "calendar.range"))
        }

        let duplicate = [base.events[0], base.events[0]]
        XCTAssertThrowsError(try presentation(snapshot(events: duplicate))) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "calendar.events"))
        }

        XCTAssertThrowsError(try presentation(snapshot(events: [base.events[1], base.events[0]]))) {
            error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "calendar.events.order")
            )
        }
    }

    func testRejectsInvalidDetailPairAndEventDuration() {
        let event = validSnapshot().events[1]
        let missingEnglishDetail = SeasonCalendarEvent(
            id: event.id,
            titleArabic: event.titleArabic,
            titleEnglish: event.titleEnglish,
            detailArabic: "تفصيل",
            detailEnglish: nil,
            startsAt: event.startsAt,
            endsAt: event.endsAt,
            kind: event.kind,
            competition: event.competition
        )
        XCTAssertThrowsError(try presentation(snapshot(events: [missingEnglishDetail]))) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "calendar.events.detail")
            )
        }

        let tooLong = SeasonCalendarEvent(
            id: event.id,
            titleArabic: event.titleArabic,
            titleEnglish: event.titleEnglish,
            detailArabic: nil,
            detailEnglish: nil,
            startsAt: date(day: 20),
            endsAt: date(day: 141),
            kind: .transferWindow,
            competition: nil
        )
        XCTAssertThrowsError(try presentation(snapshot(events: [tooLong]))) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "calendar.events.endsAt")
            )
        }
    }

    func testRejectsUnboundedOrControlCharacterDisplayText() {
        let event = validSnapshot().events[1]
        let unboundedTitle = SeasonCalendarEvent(
            id: event.id,
            titleArabic: String(repeating: "ا", count: 161),
            titleEnglish: event.titleEnglish,
            detailArabic: nil,
            detailEnglish: nil,
            startsAt: event.startsAt,
            endsAt: event.endsAt,
            kind: event.kind,
            competition: event.competition
        )
        XCTAssertThrowsError(try presentation(snapshot(events: [unboundedTitle]))) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "calendar.events")
            )
        }

        let controlCharacterDetail = SeasonCalendarEvent(
            id: event.id,
            titleArabic: event.titleArabic,
            titleEnglish: event.titleEnglish,
            detailArabic: "تفصيل\u{0007}",
            detailEnglish: "Detail",
            startsAt: event.startsAt,
            endsAt: event.endsAt,
            kind: event.kind,
            competition: event.competition
        )
        XCTAssertThrowsError(
            try presentation(snapshot(events: [controlCharacterDetail]))
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "calendar.events.detail")
            )
        }
    }

    private func presentation(
        _ snapshot: SeasonCalendarSnapshot
    ) throws -> SeasonCalendarPresentation {
        try SeasonCalendarPresentation(
            snapshot: snapshot,
            scope: .fullSeason,
            selectedKind: nil,
            referenceDate: date(day: 10),
            calendar: calendar
        )
    }

    private func validSnapshot() -> SeasonCalendarSnapshot {
        snapshot(events: [
            event(id: "kickoff", day: 5, kind: .competitionMilestone),
            event(id: "draw", day: 10, kind: .draw),
            event(id: "window", day: 20, endDay: 40, kind: .transferWindow),
            event(id: "break", day: 50, endDay: 55, kind: .internationalBreak)
        ])
    }

    private func snapshot(events: [SeasonCalendarEvent]) -> SeasonCalendarSnapshot {
        SeasonCalendarSnapshot(
            rangeStart: date(day: 1),
            rangeEnd: date(day: 100),
            updatedAt: date(day: 2),
            sourceName: "Test calendar provider",
            events: events
        )
    }

    private func event(
        id: String,
        day: Int,
        endDay: Int? = nil,
        kind: SeasonCalendarEventKind
    ) -> SeasonCalendarEvent {
        SeasonCalendarEvent(
            id: id,
            titleArabic: "موعد \(id)",
            titleEnglish: "Event \(id)",
            detailArabic: nil,
            detailEnglish: nil,
            startsAt: date(day: day),
            endsAt: endDay.map { date(day: $0) },
            kind: kind,
            competition: nil
        )
    }

    private func date(day: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day * 86_400))
    }
}
