import Foundation

enum SearchResultScope: String, CaseIterable, Hashable, Identifiable {
    case all
    case article
    case video
    case team
    case player
    case competition

    var id: String { rawValue }
    var localizationKey: String { "search.scope.\(rawValue)" }

    var systemImage: String {
        entityType?.systemImage ?? "square.grid.2x2.fill"
    }

    var entityType: SearchEntityType? {
        switch self {
        case .all: nil
        case .article: .article
        case .video: .video
        case .team: .team
        case .player: .player
        case .competition: .competition
        }
    }
}

struct SearchResultsPresentation {
    let orderedResults: [SearchResultItem]
    let selectedScope: SearchResultScope
    let availableScopes: [SearchResultScope]

    init(results: [SearchResultItem], selectedScope: SearchResultScope) {
        orderedResults = results
        let representedTypes = Set(results.map(\.type))
        availableScopes = SearchResultScope.allCases.filter { scope in
            guard let type = scope.entityType else { return true }
            return representedTypes.contains(type)
        }
        self.selectedScope = availableScopes.contains(selectedScope) ? selectedScope : .all
    }

    var visibleResults: [SearchResultItem] {
        guard let type = selectedScope.entityType else { return orderedResults }
        return orderedResults.filter { $0.type == type }
    }

    var loadedCount: Int { orderedResults.count }

    func count(for scope: SearchResultScope) -> Int {
        guard let type = scope.entityType else { return loadedCount }
        return orderedResults.lazy.filter { $0.type == type }.count
    }
}
