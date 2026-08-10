import SwiftUI

struct FollowingTeamSnapshotCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let snapshot: TeamMatchSnapshot
    let follow: SportsFollow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    matchSlot(
                        title: "following.teamDashboard.previous",
                        emptyKey: "following.teamDashboard.noPrevious",
                        systemImage: "backward.end.fill",
                        fixture: snapshot.previousFixture,
                        identifier: "previous"
                    )
                    matchSlot(
                        title: "following.teamDashboard.next",
                        emptyKey: "following.teamDashboard.noNext",
                        systemImage: "forward.end.fill",
                        fixture: snapshot.nextFixture,
                        identifier: "next"
                    )
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    matchSlot(
                        title: "following.teamDashboard.previous",
                        emptyKey: "following.teamDashboard.noPrevious",
                        systemImage: "backward.end.fill",
                        fixture: snapshot.previousFixture,
                        identifier: "previous"
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    matchSlot(
                        title: "following.teamDashboard.next",
                        emptyKey: "following.teamDashboard.noNext",
                        systemImage: "forward.end.fill",
                        fixture: snapshot.nextFixture,
                        identifier: "next"
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("following.teamDashboard.\(snapshot.team.id)")
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                teamLink
                unfollowButton(expands: true)
            }
        } else {
            HStack(spacing: 12) {
                teamLink
                unfollowButton(expands: false)
            }
        }
    }

    private var teamLink: some View {
        NavigationLink {
            TeamDetailView(team: snapshot.team)
        } label: {
            HStack(spacing: 12) {
                TeamBadge(team: snapshot.team, size: 46)
                Text(snapshot.team.displayName(in: appModel.language))
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("accessibility.opensTeam"))
        .accessibilityIdentifier(
            "following.teamDashboard.team.\(snapshot.team.id)"
        )
    }

    private func unfollowButton(expands: Bool) -> some View {
        let isBusy = appModel.isFollowMutationInProgress(
            type: .team,
            entityID: follow.entityID
        )
        return Button {
            appModel.toggleFollow(
                type: .team,
                entityID: follow.entityID,
                entity: .team(snapshot.team)
            )
        } label: {
            if isBusy {
                ProgressView()
                    .frame(
                        minWidth: 44,
                        maxWidth: expands ? .infinity : nil,
                        minHeight: 44
                    )
            } else if expands {
                Label("action.unfollow", systemImage: "star.slash")
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Image(systemName: "star.slash")
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.bordered)
        .disabled(isBusy)
        .accessibilityLabel(
            Text("action.unfollow")
                + Text(" ")
                + Text(snapshot.team.displayName(in: appModel.language))
        )
        .accessibilityHint(Text("following.unfollowHint"))
        .accessibilityIdentifier(
            "following.teamDashboard.unfollow.\(snapshot.team.id)"
        )
    }

    @ViewBuilder
    private func matchSlot(
        title: LocalizedStringKey,
        emptyKey: LocalizedStringKey,
        systemImage: String,
        fixture: Fixture?,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .accessibilityAddTraits(.isHeader)

            if let fixture {
                NavigationLink {
                    MatchCenterView(fixtureID: fixture.id)
                } label: {
                    fixtureSummary(fixture)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("accessibility.opensMatch"))
                .accessibilityIdentifier(
                    "following.teamDashboard.\(snapshot.team.id).\(identifier).\(fixture.id)"
                )
            } else {
                Label(emptyKey, systemImage: "calendar.badge.minus")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier(
                        "following.teamDashboard.\(snapshot.team.id).\(identifier).empty"
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fixtureSummary(_ fixture: Fixture) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(fixture.competition.displayName(in: appModel.language))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(2)

            Text(opponent(in: fixture).displayName(in: appModel.language))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)

            if let score = fixture.scoreText {
                Text(score)
                    .font(.headline.monospacedDigit())
            } else {
                Text(
                    fixture.kickoff,
                    format: .dateTime
                        .day()
                        .month(.abbreviated)
                        .hour()
                        .minute()
                        .locale(appModel.language.locale)
                )
                .font(.subheadline.monospacedDigit())
            }

            Text(LocalizedStringKey(fixture.state.localizationKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func opponent(in fixture: Fixture) -> Team {
        fixture.homeTeam.id == snapshot.team.id ? fixture.awayTeam : fixture.homeTeam
    }
}
