import Foundation
import SwiftUI

struct MatchesView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var dateRail = MatchesDateRail(
        centerDate: Date(),
        selectedDate: Date()
    )
    @State private var referenceDate = Date()
    @State private var statusFilter: MatchesStatusFilter = .all
    @State private var selectedScope: MatchesScope = .all
    @State private var selectedCompetitionID: String?
    @State private var calendarPresented = false
    @State private var searchPresented = false
    @State private var fixtures: [Fixture]?
    @State private var failed = false
    @State private var freshness: PublicContentFreshness?
    @State private var loadRequestID: UUID?
    @State private var followLoadRequestID: UUID?
    @State private var followsReady = false
    @State private var followSyncFailed = false
    @AccessibilityFocusState private var freshnessFocused: Bool
    @AccessibilityFocusState private var followErrorFocused: Bool

    private var selectedDate: Date {
        dateRail.selectedDate
    }

    private var presentation: MatchesPresentation {
        MatchesPresentation(
            fixtures: fixtures ?? [],
            statusFilter: statusFilter,
            selectedCompetitionID: selectedCompetitionID,
            scope: selectedScope,
            follows: followsReady ? appModel.orderedFollows : []
        )
    }

    private var searchableFixtures: [Fixture] {
        presentation.groups.flatMap(\.fixtures)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                dayPicker
                statusFilterPicker
                scopeFilterPicker
                if presentation.availableCompetitions.count > 1 {
                    competitionFilterPicker(presentation.availableCompetitions)
                }
                if let freshness {
                    PublicContentStatusView(freshness: freshness, identifier: "matches")
                        .accessibilityFocused($freshnessFocused)
                }
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await load(announceFreshness: true) }
        .background(AppTheme.background)
        .navigationTitle("matches.title")
        .accessibilityIdentifier("matches.screen")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    searchPresented = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel(Text("matches.searchTitle"))
                .accessibilityHint(Text("matches.searchButtonHint"))
                .accessibilityIdentifier("matches.toolbar.search")

                Button {
                    calendarPresented = true
                } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel(Text("matches.calendarTitle"))
                .accessibilityHint(Text("matches.calendarButtonHint"))
                .accessibilityIdentifier("matches.toolbar.calendar")
            }
        }
        .sheet(isPresented: $calendarPresented) {
            MatchesCalendarSheet(selectedDate: selectedDate) { date in
                selectDate(date, recenter: true)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $searchPresented) {
            MatchesSearchView(
                fixtures: searchableFixtures,
                date: selectedDate,
                followReasonsByFixtureID: presentation.followReasonsByFixtureID
            )
        }
        .task(id: selectedDate) { await load() }
        .task { await synchronizeMatchesFollows() }
        .onReceive(
            NotificationCenter.default.publisher(for: .authenticationStateDidChange)
        ) { _ in
            followLoadRequestID = nil
            followsReady = false
            followSyncFailed = false
            selectedScope = .all
            followErrorFocused = false
            Task { await synchronizeMatchesFollows() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshReferenceDate()
        }
    }

    @ViewBuilder
    private var scopeFilterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("matches.scopeFilterTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(MatchesScope.allCases) { item in
                        scopeFilterButton(item)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(MatchesScope.allCases) { item in
                        scopeFilterButton(item)
                    }
                }
            }

            if followSyncFailed {
                followSyncFailure
            } else if !followsReady {
                ProgressView("matches.loadingFollows")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityIdentifier("matches.scope.loading")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matches.scopeFilters")
    }

    private var followSyncFailure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("matches.followsLoadFailed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("matches.followsLoadFailedBody")
                .font(.caption)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Button("matches.retryFollows") {
                followSyncFailed = false
                followErrorFocused = false
                Task { await synchronizeMatchesFollows() }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("matches.scope.retry")
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityFocused($followErrorFocused)
        .accessibilityIdentifier("matches.scope.error")
    }

    private func scopeFilterButton(_ item: MatchesScope) -> some View {
        let isSelected = selectedScope == item
        let isWaitingForFollows = item == .following && !followsReady
        let hintKey: LocalizedStringKey
        if item == .following, followSyncFailed {
            hintKey = "matches.followingFailedHint"
        } else if isWaitingForFollows {
            hintKey = "matches.followingLoadingHint"
        } else {
            hintKey = "matches.scopeFilterHint"
        }

        return Button {
            selectedScope = item
        } label: {
            Label(
                LocalizedStringKey(item.localizationKey),
                systemImage: isSelected
                    ? "checkmark.circle.fill"
                    : item == .following
                        ? "star"
                        : "rectangle.stack"
            )
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isWaitingForFollows)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text(hintKey))
        .accessibilityIdentifier("matches.scope.\(item.rawValue)")
    }

    @ViewBuilder
    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("matches.dateFilterTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(
                selectedDate,
                format: .dateTime.weekday(.wide).day().month(.wide).year()
            )
            .font(.subheadline)
            .foregroundStyle(AppTheme.muted)
            .accessibilityIdentifier("matches.selectedDate")

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(MatchesDateRail.offsets, id: \.self) { offset in
                        dayButton(offset: offset, expands: true)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MatchesDateRail.offsets, id: \.self) { offset in
                            dayButton(offset: offset, expands: false)
                        }
                    }
                }
                .accessibilityIdentifier("matches.days.scroll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matches.days")
    }

    private func dayButton(offset: Int, expands: Bool) -> some View {
        let date = dateRail.date(at: offset)
        let isSelected = dateRail.isSelected(date)
        return Button {
            selectDate(date, recenter: false)
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    dayTitle(date: date)
                }
                .font(.subheadline.weight(.semibold))

                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption)
            }
            .frame(
                minWidth: expands ? 44 : 88,
                maxWidth: expands ? .infinity : nil,
                minHeight: 52,
                alignment: .center
            )
            .padding(.horizontal, 10)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("matches.dayHint"))
        .accessibilityIdentifier("matches.day.\(offset)")
    }

    @ViewBuilder
    private func dayTitle(date: Date) -> some View {
        switch dateRail.relativeDay(for: date, today: referenceDate) {
        case .yesterday:
            Text("matches.yesterday")
        case .today:
            Text("matches.today")
        case .tomorrow:
            Text("matches.tomorrow")
        case nil:
            Text(date, format: .dateTime.weekday(.abbreviated))
        }
    }

    @ViewBuilder
    private var statusFilterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("matches.statusFilterTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(MatchesStatusFilter.allCases) { item in
                        statusFilterButton(item, expands: true)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(MatchesStatusFilter.allCases) { item in
                        statusFilterButton(item, expands: true)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matches.statusFilters")
    }

    private func statusFilterButton(
        _ item: MatchesStatusFilter,
        expands: Bool
    ) -> some View {
        let isSelected = statusFilter == item
        return Button {
            statusFilter = item
        } label: {
            Label(
                LocalizedStringKey(item.localizationKey),
                systemImage: isSelected
                    ? "checkmark.circle.fill"
                    : item == .live
                        ? "dot.radiowaves.left.and.right"
                        : "list.bullet"
            )
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: expands ? .infinity : nil,
                minHeight: 44
            )
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("matches.statusFilterHint"))
        .accessibilityIdentifier("matches.status.\(item.rawValue)")
    }

    @ViewBuilder
    private func competitionFilterPicker(
        _ competitions: [Competition]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("matches.competitionFilterTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    competitionFilterButton(nil, expands: true)
                    ForEach(competitions) { competition in
                        competitionFilterButton(competition, expands: true)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        competitionFilterButton(nil, expands: false)
                        ForEach(competitions) { competition in
                            competitionFilterButton(competition, expands: false)
                        }
                    }
                }
                .accessibilityIdentifier("matches.competitions.scroll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matches.competitions")
    }

    private func competitionFilterButton(
        _ competition: Competition?,
        expands: Bool
    ) -> some View {
        let competitionID = competition?.id
        let isSelected = selectedCompetitionID == competitionID
        return Button {
            selectedCompetitionID = competitionID
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "trophy")
                if let competition {
                    Text(competition.displayName(in: appModel.language))
                } else {
                    Text("matches.allCompetitions")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: expands ? .infinity : nil,
                minHeight: 44,
                alignment: .leading
            )
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("matches.competitionFilterHint"))
        .accessibilityIdentifier(
            "matches.competition.\(competitionID ?? "all")"
        )
    }

    @ViewBuilder
    private var content: some View {
        if failed, fixtures == nil {
            LoadStateView(state: .error) {
                Task { await load(announceFreshness: true) }
            }
            .frame(minHeight: 280)
        } else if fixtures == nil {
            LoadStateView(state: .loading)
                .frame(minHeight: 280)
        } else if let emptyReason = presentation.emptyReason {
            matchesEmptyView(emptyReason)
        } else {
            ForEach(presentation.groups) { group in
                competitionGroup(group)
            }
        }
    }

    private func competitionGroup(_ group: CompetitionFixtureGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            competitionGroupHeader(group.competition)
            ForEach(group.fixtures) { fixture in
                NavigationLink {
                    MatchCenterView(fixtureID: fixture.id)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let reason = presentation.followReasonsByFixtureID[fixture.id] {
                            MatchesFollowReasonLabel(
                                reason: reason,
                                identifier: "matches.followReason.\(fixture.id)"
                            )
                        }
                        FixtureCard(fixture: fixture, showsCompetition: false)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("matches.fixture.\(fixture.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matches.group.\(group.id)")
    }

    @ViewBuilder
    private func matchesEmptyView(_ reason: MatchesEmptyReason) -> some View {
        if let descriptionKey = reason.descriptionLocalizationKey {
            ContentUnavailableView(
                LocalizedStringKey(reason.localizationKey),
                systemImage: emptySystemImage(for: reason),
                description: Text(LocalizedStringKey(descriptionKey))
            )
            .frame(maxWidth: .infinity, minHeight: 280)
            .accessibilityIdentifier("matches.empty.\(reason.rawValue)")
        } else {
            ContentUnavailableView(
                LocalizedStringKey(reason.localizationKey),
                systemImage: emptySystemImage(for: reason)
            )
            .frame(maxWidth: .infinity, minHeight: 280)
            .accessibilityIdentifier("matches.empty.\(reason.rawValue)")
        }
    }

    private func emptySystemImage(for reason: MatchesEmptyReason) -> String {
        switch reason {
        case .date:
            "calendar.badge.clock"
        case .live, .liveInCompetition:
            "dot.radiowaves.left.and.right"
        case .noMatchableFollows:
            "star.slash"
        case .following, .followingInCompetition:
            "line.3.horizontal.decrease.circle"
        }
    }

    @ViewBuilder
    private func competitionGroupHeader(_ competition: Competition) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                competitionTitle(competition)
                competitionDetailLink(competition)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                competitionTitle(competition)
                Spacer(minLength: 8)
                competitionDetailLink(competition)
            }
        }
    }

    private func competitionTitle(_ competition: Competition) -> some View {
        Label(
            competition.displayName(in: appModel.language),
            systemImage: "trophy.fill"
        )
        .font(.title3.weight(.bold))
        .foregroundStyle(Color.primary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("matches.groupTitle.\(competition.id)")
    }

    private func competitionDetailLink(_ competition: Competition) -> some View {
        NavigationLink {
            CompetitionDetailView(competition: competition)
        } label: {
            Label("matches.competitionDetails", systemImage: "chevron.forward")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("matches.competitionDetails.\(competition.id)")
    }

    @MainActor
    private func load(announceFreshness: Bool = false) async {
        let requestID = UUID()
        loadRequestID = requestID
        let date = selectedDate
        let resource = PublicContentResource.fixtures(on: date)
        if fixtures == nil || !announceFreshness {
            fixtures = nil
            freshness = nil
        }
        failed = false
        do {
            let loadedFixtures = try await appModel.dataProvider.fixtures(on: date)
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            let normalizedSelection = MatchesPresentation(
                fixtures: loadedFixtures,
                statusFilter: statusFilter,
                selectedCompetitionID: selectedCompetitionID
            ).selectedCompetitionID
            if normalizedSelection != selectedCompetitionID {
                selectedCompetitionID = normalizedSelection
            }
            fixtures = loadedFixtures
        } catch {
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            failed = true
        }
        let updated = await appModel.publicContentFreshness(for: resource)
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshness = updated
        guard announceFreshness || updated?.requiresAttention == true else { return }
        freshnessFocused = false
        await Task.yield()
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshnessFocused = updated != nil
    }

    @MainActor
    private func synchronizeMatchesFollows() async {
        let requestID = UUID()
        followLoadRequestID = requestID
        followSyncFailed = false
        await appModel.synchronizeFollows()
        guard followLoadRequestID == requestID, !Task.isCancelled else { return }
        let failed = appModel.followError != nil
        followSyncFailed = failed
        followsReady = !failed
        guard failed else { return }
        followErrorFocused = false
        await Task.yield()
        guard followLoadRequestID == requestID, !Task.isCancelled else { return }
        followErrorFocused = true
    }

    @MainActor
    private func refreshReferenceDate() {
        let now = Date()
        let calendar = dateRail.calendar
        guard !calendar.isDate(referenceDate, inSameDayAs: now) else { return }

        let selectionFollowedToday = calendar.isDate(
            dateRail.selectedDate,
            inSameDayAs: referenceDate
        ) && calendar.isDate(
            dateRail.centerDate,
            inSameDayAs: referenceDate
        )
        referenceDate = now
        if selectionFollowedToday {
            selectDate(now, recenter: true)
        }
    }

    @MainActor
    private func selectDate(_ date: Date, recenter: Bool) {
        let updatedRail = dateRail.selecting(date, recenter: recenter)
        guard updatedRail != dateRail else { return }

        loadRequestID = nil
        fixtures = nil
        freshness = nil
        failed = false
        dateRail = updatedRail
    }
}
