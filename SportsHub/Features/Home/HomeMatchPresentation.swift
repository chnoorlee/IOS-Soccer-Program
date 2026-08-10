import Foundation

enum HomeMatchFilter: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all
    case live
    case upcoming
    case finished
    case postponed
    case cancelled

    var id: String { rawValue }
    var localizationKey: String { "home.matches.filter.\(rawValue)" }

    func includes(_ state: FixtureState) -> Bool {
        switch self {
        case .all:
            true
        case .live:
            state == .live || state == .halfTime
        case .upcoming:
            state == .upcoming
        case .finished:
            state == .finished
        case .postponed:
            state == .postponed
        case .cancelled:
            state == .cancelled
        }
    }

    static func availableFilters(in fixtures: [Fixture]) -> [HomeMatchFilter] {
        allCases.filter { filter in
            filter == .all || fixtures.contains { filter.includes($0.state) }
        }
    }
}

struct HomeMatchPresentation: Equatable, Sendable {
    let availableFilters: [HomeMatchFilter]
    let selectedFilter: HomeMatchFilter
    let relatedFixtures: [HomeRelatedFixture]
    let generalFixtures: [Fixture]

    init(
        personalization: HomePersonalization,
        selectedFilter requestedFilter: HomeMatchFilter
    ) {
        let sourceFixtures = personalization.relatedFixtures.map(\.fixture)
            + personalization.generalFixtures
        let availableFilters = HomeMatchFilter.availableFilters(in: sourceFixtures)
        let selectedFilter = availableFilters.contains(requestedFilter)
            ? requestedFilter
            : .all

        self.availableFilters = availableFilters
        self.selectedFilter = selectedFilter
        relatedFixtures = personalization.relatedFixtures.filter {
            selectedFilter.includes($0.fixture.state)
        }
        generalFixtures = personalization.generalFixtures.filter {
            selectedFilter.includes($0.state)
        }
    }
}
