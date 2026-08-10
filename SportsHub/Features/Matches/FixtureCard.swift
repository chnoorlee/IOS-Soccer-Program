import SwiftUI

struct FixtureCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let fixture: Fixture
    var showsCompetition = true

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                if showsCompetition {
                    Text(fixture.competition.displayName(in: appModel.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }
                Spacer()
                StatusPill(
                    text: LocalizedStringKey(fixture.state.localizationKey),
                    color: fixture.state == .live || fixture.state == .halfTime
                        ? AppTheme.live
                        : AppTheme.accent
                )
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    teamRow(fixture.homeTeam)
                    matchSummary
                        .frame(maxWidth: .infinity, alignment: .leading)
                    teamRow(fixture.awayTeam)
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    teamColumn(fixture.homeTeam)

                    matchSummary
                        .frame(minWidth: 72)

                    teamColumn(fixture.awayTeam)
                }
            }

            if !fixture.broadcasts.isEmpty {
                broadcastSummary
            }
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("accessibility.opensMatch"))
    }

    private var broadcastSummary: some View {
        let first = fixture.broadcasts[0]
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    broadcastChannel(first)
                    broadcastAdditionalCount
                }
            } else {
                HStack(spacing: 8) {
                    broadcastChannel(first)
                    broadcastAdditionalCount
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fixture.broadcasts.\(fixture.id)")
    }

    private func broadcastChannel(_ broadcast: FixtureBroadcast) -> some View {
        Label {
            Text(verbatim: broadcast.channel(in: appModel.language))
                .font(.caption.weight(.semibold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var broadcastAdditionalCount: some View {
        if fixture.broadcasts.count > 1 {
            Text(
                localizedFormat(
                    "match.broadcast.moreOptions",
                    fixture.broadcasts.count - 1
                )
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func localizedFormat(_ key: String.LocalizationValue, _ value: Int) -> String {
        String(
            format: String(localized: key, locale: appModel.language.locale),
            value
        )
    }

    private var matchSummary: some View {
        VStack(alignment: .center, spacing: 4) {
            if let score = fixture.scoreText {
                Text(score)
                    .font(.title2.monospacedDigit().weight(.black))
            } else {
                Text(fixture.kickoff, format: .dateTime.hour().minute())
                    .font(.headline.monospacedDigit())
            }

            if let minute = fixture.minute, fixture.state == .live {
                Text("\(minute)′")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.live)
            } else {
                Text(fixture.kickoff, format: .dateTime.day().month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func teamRow(_ team: Team) -> some View {
        HStack(spacing: 12) {
            TeamBadge(team: team, size: 42)
            Text(team.displayName(in: appModel.language))
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private func teamColumn(_ team: Team) -> some View {
        VStack(spacing: 8) {
            TeamBadge(team: team, size: 46)
            Text(team.displayName(in: appModel.language))
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}
