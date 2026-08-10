import SwiftUI

struct SeasonCalendarView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var snapshot: SeasonCalendarSnapshot?
    @State private var selectedScope: SeasonCalendarScope = .upcoming
    @State private var selectedKind: SeasonCalendarEventKind?
    @State private var referenceDate = Date()
    @State private var freshness: PublicContentFreshness?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var requestID: UUID?
    @AccessibilityFocusState private var errorFocused: Bool
    @AccessibilityFocusState private var freshnessFocused: Bool

    private var presentation: SeasonCalendarPresentation? {
        guard let snapshot else { return nil }
        return try? SeasonCalendarPresentation(
            snapshot: snapshot,
            scope: selectedScope,
            selectedKind: selectedKind,
            referenceDate: referenceDate
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let presentation {
                    evidenceBoundary(presentation.snapshot)
                    filterControls(presentation)

                    if let freshness {
                        PublicContentStatusView(
                            freshness: freshness,
                            identifier: "seasonCalendar"
                        )
                        .accessibilityFocused($freshnessFocused)
                    }

                    calendarContent(presentation)
                } else if isLoading {
                    LoadStateView(state: .loading)
                        .accessibilityIdentifier("seasonCalendar.loading")
                } else {
                    LoadStateView(state: .error) {
                        Task { await load(announceFreshness: true) }
                    }
                    .accessibilityFocused($errorFocused)
                    .accessibilityIdentifier("seasonCalendar.error")
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("seasonCalendar.title")
        .accessibilityIdentifier("seasonCalendar.screen")
        .refreshable { await load(announceFreshness: true) }
        .task { await load() }
    }

    private func evidenceBoundary(_ snapshot: SeasonCalendarSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(AppTheme.warm.opacity(0.20))
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.warm)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("seasonCalendar.boundaryTitle")
                        .font(.headline)
                    Text("seasonCalendar.boundaryBody")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .overlay(.white.opacity(0.20))

            VStack(alignment: .leading, spacing: 5) {
                Text("seasonCalendar.sourceLabel")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.warm)
                Text(snapshot.sourceName)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(calendarWindowText(snapshot))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                Text("seasonCalendar.updatedLabel")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.warm)
                Text(
                    snapshot.updatedAt,
                    format: .dateTime
                        .day()
                        .month(.wide)
                        .year()
                        .hour()
                        .minute()
                        .locale(appModel.language.locale)
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.78))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.ink)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("seasonCalendar.boundary")
    }

    private func filterControls(_ presentation: SeasonCalendarPresentation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            controlGroup(title: "seasonCalendar.scopeTitle") {
                ForEach(SeasonCalendarScope.allCases) { scope in
                    scopeButton(scope)
                }
            }

            controlGroup(title: "seasonCalendar.filterTitle") {
                kindButton(nil)
                ForEach(presentation.availableKinds) { kind in
                    kindButton(kind)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("seasonCalendar.controls")
    }

    @ViewBuilder
    private func controlGroup<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) { content() }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { content() }
                }
            }
        }
    }

    private func scopeButton(_ scope: SeasonCalendarScope) -> some View {
        let isSelected = selectedScope == scope
        return Button {
            selectedScope = scope
        } label: {
            Label(
                LocalizedStringKey(scope.localizationKey),
                systemImage: isSelected ? "checkmark.circle.fill" : "calendar"
            )
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
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
        .accessibilityHint(Text("seasonCalendar.controlHint"))
        .accessibilityIdentifier("seasonCalendar.scope.\(scope.rawValue)")
    }

    private func kindButton(_ kind: SeasonCalendarEventKind?) -> some View {
        let isSelected = selectedKind == kind
        let key = kind?.localizationKey ?? "seasonCalendar.filterAll"
        return Button {
            selectedKind = kind
        } label: {
            Label(
                LocalizedStringKey(key),
                systemImage: isSelected ? "checkmark.circle.fill" : kindSystemImage(kind)
            )
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                minHeight: 44,
                alignment: .leading
            )
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : kindColor(kind))
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("seasonCalendar.controlHint"))
        .accessibilityIdentifier("seasonCalendar.kind.\(kind?.rawValue ?? "all")")
    }

    @ViewBuilder
    private func calendarContent(_ presentation: SeasonCalendarPresentation) -> some View {
        if loadFailed {
            inlineFailure
        }

        if presentation.visibleEvents.isEmpty {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "seasonCalendar.emptyTitle",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("seasonCalendar.emptyBody")
                )
                if selectedScope == .upcoming && !presentation.snapshot.events.isEmpty {
                    Button("seasonCalendar.showFullSeason") {
                        selectedScope = .fullSeason
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("seasonCalendar.showFullSeason")
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("seasonCalendar.empty")
        } else {
            ForEach(presentation.monthGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        group.monthStart,
                        format: .dateTime
                            .month(.wide)
                            .year()
                            .locale(appModel.language.locale)
                    )
                    .font(.title3.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .accessibilityAddTraits(.isHeader)

                    ForEach(group.events.indices, id: \.self) { index in
                        eventDestination(
                            group.events[index],
                            showsContinuation: index < group.events.count - 1
                        )
                    }
                }
                .accessibilityIdentifier("seasonCalendar.month.\(group.id.timeIntervalSince1970)")
            }
        }
    }

    @ViewBuilder
    private func eventDestination(
        _ event: SeasonCalendarEvent,
        showsContinuation: Bool
    ) -> some View {
        if let competition = event.competition {
            NavigationLink {
                CompetitionDetailView(competition: competition)
            } label: {
                SeasonCalendarTimelineRow(
                    event: event,
                    showsContinuation: showsContinuation,
                    showsDisclosure: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("seasonCalendar.eventHint"))
            .accessibilityIdentifier("seasonCalendar.event.\(event.id)")
        } else {
            SeasonCalendarTimelineRow(
                event: event,
                showsContinuation: showsContinuation,
                showsDisclosure: false
            )
            .accessibilityIdentifier("seasonCalendar.event.\(event.id)")
        }
    }

    private var inlineFailure: some View {
        HStack(spacing: 10) {
            Label("seasonCalendar.refreshFailed", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            Spacer(minLength: 0)
            Button("seasonCalendar.retry") {
                Task { await load(announceFreshness: true) }
            }
            .font(.caption.weight(.bold))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(AppTheme.warm.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func kindColor(_ kind: SeasonCalendarEventKind?) -> Color {
        switch kind {
        case nil: AppTheme.ink
        case .some(.competitionMilestone): AppTheme.accent
        case .some(.draw): .indigo
        case .some(.transferWindow): AppTheme.warm
        case .some(.internationalBreak): .purple
        case .some(.other): AppTheme.muted
        }
    }

    private func kindSystemImage(_ kind: SeasonCalendarEventKind?) -> String {
        switch kind {
        case nil: "square.grid.2x2.fill"
        case .some(.competitionMilestone): "flag.checkered"
        case .some(.draw): "circle.grid.cross.fill"
        case .some(.transferWindow): "arrow.left.arrow.right"
        case .some(.internationalBreak): "globe.europe.africa.fill"
        case .some(.other): "calendar.badge.clock"
        }
    }

    private func calendarWindowText(_ snapshot: SeasonCalendarSnapshot) -> String {
        let style = Date.FormatStyle(date: .long, time: .omitted)
            .locale(appModel.language.locale)
        return "\(snapshot.rangeStart.formatted(style)) – \(snapshot.rangeEnd.formatted(style))"
    }

    @MainActor
    private func load(announceFreshness: Bool = false) async {
        let activeRequestID = UUID()
        requestID = activeRequestID
        isLoading = snapshot == nil
        loadFailed = false
        errorFocused = false
        do {
            let value = try await appModel.dataProvider.seasonCalendar()
            let now = Date()
            let normalized = try SeasonCalendarPresentation(
                snapshot: value,
                scope: selectedScope,
                selectedKind: selectedKind,
                referenceDate: now
            )
            guard requestID == activeRequestID, !Task.isCancelled else { return }
            snapshot = value
            referenceDate = now
            if let selectedKind, !normalized.availableKinds.contains(selectedKind) {
                self.selectedKind = nil
            }
            let reportedFreshness = await appModel.publicContentFreshness(for: .seasonCalendar)
            guard requestID == activeRequestID, !Task.isCancelled else { return }
            freshness = reportedFreshness
            isLoading = false
            if announceFreshness || freshness?.requiresAttention == true {
                freshnessFocused = false
                await Task.yield()
                guard requestID == activeRequestID, !Task.isCancelled else { return }
                freshnessFocused = freshness != nil
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestID == activeRequestID else { return }
            let reportedFreshness = await appModel.publicContentFreshness(for: .seasonCalendar)
            guard requestID == activeRequestID, !Task.isCancelled else { return }
            freshness = reportedFreshness
            isLoading = false
            loadFailed = true
            if snapshot == nil {
                errorFocused = true
            }
        }
    }
}

private struct SeasonCalendarTimelineRow: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let event: SeasonCalendarEvent
    let showsContinuation: Bool
    let showsDisclosure: Bool

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleLayout
            } else {
                compactLayout
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var compactLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            dateBadge
                .frame(width: 54)

            VStack(spacing: 0) {
                Circle()
                    .fill(kindColor)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(AppTheme.background, lineWidth: 3))
                if showsContinuation {
                    Rectangle()
                        .fill(kindColor.opacity(0.24))
                        .frame(width: 2, height: 86)
                }
            }
            .padding(.top, 16)
            .accessibilityHidden(true)

            eventCard
        }
    }

    private var accessibleLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                dateBadge
                Text(LocalizedStringKey(event.kind.localizationKey))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(kindColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(kindColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            eventCard
        }
    }

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(
                event.startsAt,
                format: .dateTime.day().locale(appModel.language.locale)
            )
            .font(.title2.weight(.black))
            .monospacedDigit()
            Text(
                event.startsAt,
                format: .dateTime.month(.abbreviated).locale(appModel.language.locale)
            )
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
        }
        .foregroundStyle(kindColor)
        .frame(minWidth: 52, minHeight: 52)
        .background(kindColor.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }

    private var eventCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !dynamicTypeSize.isAccessibilitySize {
                Text(LocalizedStringKey(event.kind.localizationKey))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(kindColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(event.title(in: appModel.language))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if showsDisclosure {
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                        .accessibilityHidden(true)
                }
            }

            if let detail = event.detail(in: appModel.language) {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(eventDateText, systemImage: "clock.fill")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let competition = event.competition {
                Label(
                    competition.displayName(in: appModel.language),
                    systemImage: "trophy.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .sportsCard()
    }

    private var kindColor: Color {
        switch event.kind {
        case .competitionMilestone: AppTheme.accent
        case .draw: .indigo
        case .transferWindow: AppTheme.warm
        case .internationalBreak: .purple
        case .other: AppTheme.muted
        }
    }

    private var eventDateText: String {
        let locale = appModel.language.locale
        let start = event.startsAt.formatted(
            Date.FormatStyle(date: .long, time: .shortened).locale(locale)
        )
        guard let endsAt = event.endsAt else { return start }
        let end = endsAt.formatted(
            Date.FormatStyle(date: .long, time: .shortened).locale(locale)
        )
        return "\(start) – \(end)"
    }

    private var accessibilitySummary: String {
        let locale = appModel.language.locale
        let kind = String(localized: kindLocalizationValue, locale: locale)
        var parts = [event.title(in: appModel.language), kind, eventDateText]
        if let competition = event.competition {
            parts.append(competition.displayName(in: appModel.language))
        }
        if let detail = event.detail(in: appModel.language) {
            parts.append(detail)
        }
        return parts.joined(separator: ", ")
    }

    private var kindLocalizationValue: String.LocalizationValue {
        switch event.kind {
        case .competitionMilestone: "seasonCalendar.kind.competitionMilestone"
        case .draw: "seasonCalendar.kind.draw"
        case .transferWindow: "seasonCalendar.kind.transferWindow"
        case .internationalBreak: "seasonCalendar.kind.internationalBreak"
        case .other: "seasonCalendar.kind.other"
        }
    }
}
