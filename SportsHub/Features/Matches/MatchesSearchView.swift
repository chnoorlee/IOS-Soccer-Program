import SwiftUI

struct MatchesSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    let fixtures: [Fixture]
    let date: Date
    let followReasonsByFixtureID: [String: FixtureFollowReason]

    init(
        fixtures: [Fixture],
        date: Date,
        followReasonsByFixtureID: [String: FixtureFollowReason] = [:]
    ) {
        self.fixtures = fixtures
        self.date = date
        self.followReasonsByFixtureID = followReasonsByFixtureID
    }

    private var presentation: MatchesSearchPresentation {
        MatchesSearchPresentation(fixtures: fixtures, query: query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    searchField

                    VStack(alignment: .leading, spacing: 4) {
                        Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                            .font(.subheadline.weight(.semibold))
                        Text("matches.searchScope")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("matches.search.scope")

                    searchContent
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("matches.searchTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("matches.closeSearch") {
                        dismiss()
                    }
                    .accessibilityIdentifier("matches.search.close")
                }
            }
            .accessibilityIdentifier("matches.search.sheet")
        }
        .task {
            await Task.yield()
            searchFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.muted)
                .accessibilityHidden(true)

            TextField("matches.searchPrompt", text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(Text("matches.searchTitle"))
                .accessibilityHint(Text("matches.searchScope"))
                .accessibilityIdentifier("matches.search.field")

            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.muted)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("matches.clearSearch"))
                .accessibilityIdentifier("matches.search.clear")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, query.isEmpty ? 14 : 2)
        .frame(minHeight: 50)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var searchContent: some View {
        switch presentation.state {
        case .prompt:
            ContentUnavailableView(
                "matches.searchStart",
                systemImage: "magnifyingglass",
                description: Text("matches.searchStartBody")
            )
            .frame(maxWidth: .infinity, minHeight: 260)
            .accessibilityIdentifier("matches.search.prompt")
        case .tooShort:
            ContentUnavailableView(
                "matches.searchMoreCharacters",
                systemImage: "text.magnifyingglass",
                description: Text("matches.searchMoreCharactersBody")
            )
            .frame(maxWidth: .infinity, minHeight: 260)
            .accessibilityIdentifier("matches.search.tooShort")
        case .empty:
            ContentUnavailableView(
                "matches.searchNoResults",
                systemImage: "magnifyingglass",
                description: Text("matches.searchNoResultsBody")
            )
            .frame(maxWidth: .infinity, minHeight: 260)
            .accessibilityIdentifier("matches.search.empty")
        case .results:
            VStack(alignment: .leading, spacing: 12) {
                Text("matches.searchResults")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(presentation.fixtures) { fixture in
                    NavigationLink {
                        MatchCenterView(fixtureID: fixture.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            if let reason = followReasonsByFixtureID[fixture.id] {
                                MatchesFollowReasonLabel(
                                    reason: reason,
                                    identifier: "matches.search.followReason.\(fixture.id)"
                                )
                            }
                            FixtureCard(fixture: fixture)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("matches.search.result.\(fixture.id)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("matches.search.results")
        }
    }
}
