import Foundation

enum SeasonCalendarScope: String, CaseIterable, Hashable, Identifiable, Sendable {
    case upcoming
    case fullSeason

    var id: String { rawValue }
    var localizationKey: String { "seasonCalendar.scope.\(rawValue)" }
}

struct SeasonCalendarMonthGroup: Identifiable, Equatable, Sendable {
    let monthStart: Date
    var events: [SeasonCalendarEvent]

    var id: Date { monthStart }
}

struct SeasonCalendarPresentation {
    let snapshot: SeasonCalendarSnapshot
    let scope: SeasonCalendarScope
    let selectedKind: SeasonCalendarEventKind?
    let referenceDate: Date
    let calendar: Calendar

    init(
        snapshot: SeasonCalendarSnapshot,
        scope: SeasonCalendarScope,
        selectedKind: SeasonCalendarEventKind?,
        referenceDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) throws {
        try Self.validate(snapshot)
        self.snapshot = snapshot
        self.scope = scope
        self.selectedKind = selectedKind
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    var availableKinds: [SeasonCalendarEventKind] {
        snapshot.events.reduce(into: []) { kinds, event in
            if !kinds.contains(event.kind) {
                kinds.append(event.kind)
            }
        }
    }

    var visibleEvents: [SeasonCalendarEvent] {
        let today = calendar.startOfDay(for: referenceDate)
        return snapshot.events.filter { event in
            let matchesScope = scope == .fullSeason
                || (event.endsAt ?? event.startsAt) >= today
            let matchesKind = selectedKind == nil || event.kind == selectedKind
            return matchesScope && matchesKind
        }
    }

    var monthGroups: [SeasonCalendarMonthGroup] {
        var groups: [SeasonCalendarMonthGroup] = []
        for event in visibleEvents {
            let components = calendar.dateComponents([.era, .year, .month], from: event.startsAt)
            let monthStart = calendar.date(from: components) ?? event.startsAt
            if let lastIndex = groups.indices.last,
               calendar.isDate(groups[lastIndex].monthStart, equalTo: monthStart, toGranularity: .month) {
                groups[lastIndex].events.append(event)
            } else {
                groups.append(SeasonCalendarMonthGroup(monthStart: monthStart, events: [event]))
            }
        }
        return groups
    }

    var nextUpcomingEvent: SeasonCalendarEvent? {
        let today = calendar.startOfDay(for: referenceDate)
        return snapshot.events.first { event in
            (event.endsAt ?? event.startsAt) >= today
        }
    }

    private static func validate(_ snapshot: SeasonCalendarSnapshot) throws {
        let windowDuration = snapshot.rangeEnd.timeIntervalSince(snapshot.rangeStart)
        guard windowDuration.isFinite,
              windowDuration > 0,
              windowDuration <= SeasonCalendarDataContract.maximumWindowDuration else {
            throw SportsDataError.contractViolation(field: "calendar.range")
        }
        let sourceName = snapshot.sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sourceName == snapshot.sourceName,
              (1...SeasonCalendarDataContract.maximumSourceNameLength)
                .contains(sourceName.count),
              sourceName.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }),
              snapshot.events.count <= SeasonCalendarDataContract.maximumEventCount else {
            throw SportsDataError.contractViolation(field: "calendar.metadata")
        }

        let forbidden = CharacterSet(charactersIn: "/\\?#")
        var eventIDs = Set<String>()
        var competitionByID: [String: Competition] = [:]
        for event in snapshot.events {
            let id = event.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let titleArabic = event.titleArabic.trimmingCharacters(in: .whitespacesAndNewlines)
            let titleEnglish = event.titleEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
            guard id == event.id,
                  (1...128).contains(id.count),
                  id.rangeOfCharacter(from: forbidden) == nil,
                  id.unicodeScalars.allSatisfy({
                      !CharacterSet.controlCharacters.contains($0)
                  }),
                  eventIDs.insert(id).inserted,
                  !titleArabic.isEmpty,
                  !titleEnglish.isEmpty,
                  titleArabic.count <= SeasonCalendarDataContract.maximumTitleLength,
                  titleEnglish.count <= SeasonCalendarDataContract.maximumTitleLength,
                  [titleArabic, titleEnglish].allSatisfy({ text in
                      text.unicodeScalars.allSatisfy({
                          !CharacterSet.controlCharacters.contains($0)
                      })
                  }),
                  event.startsAt >= snapshot.rangeStart,
                  event.startsAt <= snapshot.rangeEnd else {
                throw SportsDataError.contractViolation(field: "calendar.events")
            }
            switch (event.detailArabic, event.detailEnglish) {
            case (nil, nil):
                break
            case let (.some(arabic), .some(english)):
                guard !arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      arabic.count <= SeasonCalendarDataContract.maximumDetailLength,
                      english.count <= SeasonCalendarDataContract.maximumDetailLength,
                      [arabic, english].allSatisfy({ text in
                          text.unicodeScalars.allSatisfy({
                              !CharacterSet.controlCharacters.contains($0)
                          })
                      }) else {
                    throw SportsDataError.contractViolation(field: "calendar.events.detail")
                }
            default:
                throw SportsDataError.contractViolation(field: "calendar.events.detail")
            }
            if let endsAt = event.endsAt {
                let duration = endsAt.timeIntervalSince(event.startsAt)
                guard duration.isFinite,
                      duration >= 0,
                      duration <= SeasonCalendarDataContract.maximumEventDuration,
                      endsAt <= snapshot.rangeEnd else {
                    throw SportsDataError.contractViolation(field: "calendar.events.endsAt")
                }
            }
            if let competition = event.competition {
                if let existing = competitionByID[competition.id], existing != competition {
                    throw SportsDataError.contractViolation(field: "calendar.events.competition")
                }
                competitionByID[competition.id] = competition
            }
        }
        for (current, next) in zip(snapshot.events, snapshot.events.dropFirst()) {
            guard current.startsAt < next.startsAt
                    || (current.startsAt == next.startsAt && current.id < next.id) else {
                throw SportsDataError.contractViolation(field: "calendar.events.order")
            }
        }
    }
}
