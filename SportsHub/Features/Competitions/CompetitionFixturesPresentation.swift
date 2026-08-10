import Foundation

struct CompetitionFixturesPresentation: Equatable, Sendable {
    struct Section: Identifiable, Equatable, Sendable {
        enum Kind: String, CaseIterable, Sendable {
            case live
            case upcoming
            case results
            case other

            var localizationKey: String { "competition.fixtures.\(rawValue)" }

            var systemImage: String {
                switch self {
                case .live: "dot.radiowaves.left.and.right"
                case .upcoming: "calendar.badge.clock"
                case .results: "checkmark.seal"
                case .other: "exclamationmark.arrow.triangle.2.circlepath"
                }
            }
        }

        let kind: Kind
        let fixtures: [Fixture]

        var id: Kind { kind }
    }

    let sections: [Section]

    init(fixtures: [Fixture]) {
        let grouped = Dictionary(grouping: fixtures, by: Self.sectionKind)
        sections = Section.Kind.allCases.compactMap { kind in
            guard let values = grouped[kind], !values.isEmpty else { return nil }
            let ascending = kind == .live || kind == .upcoming
            return Section(kind: kind, fixtures: values.sorted {
                if $0.kickoff == $1.kickoff { return $0.id < $1.id }
                return ascending ? $0.kickoff < $1.kickoff : $0.kickoff > $1.kickoff
            })
        }
    }

    private static func sectionKind(for fixture: Fixture) -> Section.Kind {
        switch fixture.state {
        case .live, .halfTime: .live
        case .upcoming: .upcoming
        case .finished: .results
        case .postponed, .cancelled: .other
        }
    }
}
