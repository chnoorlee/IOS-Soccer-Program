import Foundation

enum MatchesRelativeDay: Equatable, Sendable {
    case yesterday
    case today
    case tomorrow
}

struct MatchesDateRail: Equatable {
    static let offsets = Array(-2...2)

    let centerDate: Date
    let selectedDate: Date
    let calendar: Calendar

    init(
        centerDate: Date,
        selectedDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.calendar = calendar
        self.centerDate = calendar.startOfDay(for: centerDate)
        self.selectedDate = calendar.startOfDay(for: selectedDate)
    }

    var dates: [Date] {
        Self.offsets.map { date(at: $0) }
    }

    func date(at offset: Int) -> Date {
        calendar.date(
            byAdding: .day,
            value: offset,
            to: centerDate
        ) ?? centerDate
    }

    func selecting(_ date: Date, recenter: Bool) -> MatchesDateRail {
        MatchesDateRail(
            centerDate: recenter ? date : centerDate,
            selectedDate: date,
            calendar: calendar
        )
    }

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    func relativeDay(for date: Date, today referenceDate: Date) -> MatchesRelativeDay? {
        let today = calendar.startOfDay(for: referenceDate)
        if calendar.isDate(date, inSameDayAs: today) {
            return .today
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return .yesterday
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return .tomorrow
        }
        return nil
    }
}
