import SwiftUI

struct StandingsTableView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let groups: [StandingGroup]
    var highlightedTeamIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.displayName(in: appModel.language))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibleStandings(group.rows)
                    } else {
                        compactStandings(group.rows)
                    }
                }
            }
        }
    }

    private func accessibleStandings(_ rows: [StandingRow]) -> some View {
        VStack(spacing: 10) {
            ForEach(rows) { row in
                NavigationLink {
                    TeamDetailView(team: row.team)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text("#\(row.rank)")
                                .font(.title3.monospacedDigit().weight(.black))
                            TeamBadge(team: row.team, size: 38)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.team.displayName(in: appModel.language))
                                    .font(.headline)
                                if isHighlighted(row) {
                                    Label(
                                        "match.context.fixtureTeam",
                                        systemImage: "smallcircle.filled.circle"
                                    )
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        LabeledContent("standings.played", value: "\(row.played)")
                        LabeledContent(
                            "standings.record",
                            value: "\(row.won)-\(row.drawn)-\(row.lost)"
                        )
                        LabeledContent(
                            "standings.goalDifference",
                            value: signed(row.goalDifference)
                        )
                        LabeledContent("standings.points", value: "\(row.points)")
                        formView(row.form)
                    }
                    .sportsCard()
                    .overlay {
                        if isHighlighted(row) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.accent, lineWidth: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(accessibilitySummary(row)))
                .accessibilityHint(Text("accessibility.opensTeam"))
            }
        }
    }

    private func compactStandings(_ rows: [StandingRow]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                standingsHeader
                ForEach(rows) { row in
                    NavigationLink {
                        TeamDetailView(team: row.team)
                    } label: {
                        HStack(spacing: 0) {
                            Text("\(row.rank)").standingColumn(width: 36, alignment: .center)
                            HStack(spacing: 8) {
                                if isHighlighted(row) {
                                    Image(systemName: "smallcircle.filled.circle")
                                        .foregroundStyle(AppTheme.accent)
                                        .accessibilityHidden(true)
                                }
                                TeamBadge(team: row.team, size: 30)
                                Text(row.team.displayName(in: appModel.language))
                                    .lineLimit(1)
                            }
                            .standingColumn(width: 184, alignment: .leading)
                            Text("\(row.played)").standingColumn(width: 44, alignment: .center)
                            Text("\(row.won)").standingColumn(width: 44, alignment: .center)
                            Text("\(row.drawn)").standingColumn(width: 44, alignment: .center)
                            Text("\(row.lost)").standingColumn(width: 44, alignment: .center)
                            Text(signed(row.goalDifference))
                                .standingColumn(width: 52, alignment: .center)
                            Text("\(row.points)")
                                .fontWeight(.black)
                                .standingColumn(width: 52, alignment: .center)
                            formView(row.form, showsLabel: false)
                                .standingColumn(width: 152, alignment: .leading)
                        }
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                        .frame(minHeight: 50)
                        .background(rowBackground(row))
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(accessibilitySummary(row)))
                    .accessibilityHint(Text("accessibility.opensTeam"))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.muted.opacity(0.24), lineWidth: 1)
            }
        }
    }

    private var standingsHeader: some View {
        HStack(spacing: 0) {
            Text("#").standingColumn(width: 36, alignment: .center)
            Text("standings.team").standingColumn(width: 184, alignment: .leading)
            Text("standings.playedShort").standingColumn(width: 44, alignment: .center)
            Text("standings.wonShort").standingColumn(width: 44, alignment: .center)
            Text("standings.drawnShort").standingColumn(width: 44, alignment: .center)
            Text("standings.lostShort").standingColumn(width: 44, alignment: .center)
            Text("standings.goalDifferenceShort")
                .standingColumn(width: 52, alignment: .center)
            Text("standings.pointsShort").standingColumn(width: 52, alignment: .center)
            Text("standings.form").standingColumn(width: 152, alignment: .leading)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(AppTheme.muted)
        .frame(minHeight: 42)
        .background(AppTheme.surface)
        .accessibilityHidden(true)
    }

    private func formView(
        _ form: [StandingFormResult],
        showsLabel: Bool = true
    ) -> some View {
        HStack(spacing: 6) {
            if showsLabel {
                Text("standings.form")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            ForEach(Array(form.enumerated()), id: \.offset) { _, result in
                Text(LocalizedStringKey("standings.form.\(result.rawValue)Short"))
                    .font(.caption2.monospaced().weight(.bold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.white)
                    .background(formColor(result))
                    .clipShape(Circle())
                    .accessibilityLabel(Text(LocalizedStringKey(result.localizationKey)))
            }
        }
    }

    private func formColor(_ result: StandingFormResult) -> Color {
        switch result {
        case .win: AppTheme.accent
        case .draw: AppTheme.muted
        case .loss: AppTheme.live
        }
    }

    private func rowBackground(_ row: StandingRow) -> Color {
        if isHighlighted(row) {
            return AppTheme.accent.opacity(0.10)
        }
        return row.rank.isMultiple(of: 2) ? AppTheme.surface : AppTheme.background
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func isHighlighted(_ row: StandingRow) -> Bool {
        highlightedTeamIDs.contains(row.team.id)
    }

    private func accessibilitySummary(_ row: StandingRow) -> String {
        let summary = String(
            format: String(
                localized: "standings.rowAccessibility",
                locale: appModel.language.locale
            ),
            row.rank,
            row.team.displayName(in: appModel.language),
            row.played,
            row.won,
            row.drawn,
            row.lost,
            row.goalDifference,
            row.points
        )
        guard isHighlighted(row) else { return summary }
        let marker = String(
            localized: "match.context.fixtureTeam",
            locale: appModel.language.locale
        )
        return "\(summary). \(marker)"
    }
}

private extension View {
    func standingColumn(width: CGFloat, alignment: Alignment) -> some View {
        frame(width: width, alignment: alignment)
            .padding(.horizontal, 4)
    }
}
