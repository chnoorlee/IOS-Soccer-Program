import ActivityKit
import SwiftUI
import WidgetKit

struct MatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            lockScreen(context)
                .environment(\.locale, locale(for: context.state))
                .environment(
                    \.layoutDirection,
                    context.state.preferredLanguageCode == "ar"
                        ? .rightToLeft
                        : .leftToRight
                )
                .widgetURL(deepLink(for: context.attributes.fixtureID))
                .activityBackgroundTint(Color(red: 0.05, green: 0.10, blue: 0.20))
                .activitySystemActionForegroundColor(.white)
                .foregroundStyle(.white)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(context))
                .accessibilityHint(Text("activity.openHint"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    teamName(context.state.homeTeamName)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    teamName(context.state.awayTeamName)
                }
                DynamicIslandExpandedRegion(.center) {
                    scoreOrBall(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Text(context.state.statusText)
                        if let minute = context.state.minute,
                           context.state.fixtureState == WidgetMatchState.live.rawValue {
                            Text("·")
                            Text("\(minute)′")
                                .monospacedDigit()
                        }
                        if context.state.isDemo {
                            Text(verbatim: localized("activity.demo", state: context.state))
                                .foregroundStyle(Color.orange)
                        }
                        if context.isStale {
                            Text(verbatim: localized("activity.stale", state: context.state))
                                .foregroundStyle(Color.orange)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                }
            } compactLeading: {
                compactScore(
                    context.state.homeScore,
                    teamName: context.state.homeTeamName,
                    state: context.state
                )
            } compactTrailing: {
                compactScore(
                    context.state.awayScore,
                    teamName: context.state.awayTeamName,
                    state: context.state
                )
            } minimal: {
                Image(systemName: "soccerball")
                    .accessibilityLabel(accessibilityLabel(context))
                    .accessibilityHint(
                        Text(verbatim: localized("activity.openHint", state: context.state))
                    )
            }
            .widgetURL(deepLink(for: context.attributes.fixtureID))
            .keylineTint(Color(red: 0.16, green: 0.86, blue: 0.91))
        }
    }

    private func lockScreen(
        _ context: ActivityViewContext<MatchActivityAttributes>
    ) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sportscourt.fill")
                    .foregroundStyle(Color(red: 0.16, green: 0.86, blue: 0.91))
                    .accessibilityHidden(true)
                Text(context.state.competitionName)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if context.state.isDemo {
                    Text(verbatim: localized("activity.demo", state: context.state))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                }
                if context.isStale {
                    Text(verbatim: localized("activity.stale", state: context.state))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                }
            }

            HStack(alignment: .center, spacing: 12) {
                lockScreenTeam(
                    context.state.homeTeamName,
                    score: context.state.homeScore
                )
                VStack(spacing: 4) {
                    Text(context.state.statusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.16, green: 0.86, blue: 0.91))
                    if context.state.homeScore == nil {
                        Image(systemName: "soccerball")
                            .font(.title2)
                            .accessibilityHidden(true)
                    }
                    if let minute = context.state.minute,
                       context.state.fixtureState == WidgetMatchState.live.rawValue {
                        Text("\(minute)′")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
                .frame(minWidth: 72)
                lockScreenTeam(
                    context.state.awayTeamName,
                    score: context.state.awayScore
                )
            }

            Text(
                verbatim: String(
                    format: localized(
                        "activity.updatedFormat",
                        state: context.state
                    ),
                    locale: locale(for: context.state),
                    context.state.updatedAt.formatted(
                        .dateTime
                            .hour()
                            .minute()
                            .locale(locale(for: context.state))
                    )
                )
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.78))
        }
        .padding()
    }

    private func lockScreenTeam(_ name: String, score: Int?) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let score {
                Text("\(score)")
                    .font(.title2.monospacedDigit().weight(.black))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func teamName(_ name: String) -> some View {
        Text(name)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
    }

    @ViewBuilder
    private func scoreOrBall(_ state: MatchActivityAttributes.ContentState) -> some View {
        if let homeScore = state.homeScore, let awayScore = state.awayScore {
            Text("\(homeScore)–\(awayScore)")
                .font(.headline.monospacedDigit().weight(.black))
        } else {
            Image(systemName: "soccerball")
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func compactScore(
        _ score: Int?,
        teamName: String,
        state: MatchActivityAttributes.ContentState
    ) -> some View {
        if let score {
            Text("\(score)")
                .font(.caption.monospacedDigit().weight(.black))
                .accessibilityLabel(Text(verbatim: "\(teamName), \(score)"))
        } else {
            Image(systemName: "soccerball")
                .accessibilityLabel(
                    Text(
                        verbatim: "\(teamName), "
                            + localized("activity.scoreUnavailable", state: state)
                    )
                )
        }
    }

    private func accessibilityLabel(
        _ context: ActivityViewContext<MatchActivityAttributes>
    ) -> Text {
        let state = context.state
        let score: String
        if let homeScore = context.state.homeScore,
           let awayScore = context.state.awayScore {
            score = String(
                format: localized("activity.scoreFormat", state: state),
                locale: locale(for: state),
                homeScore,
                awayScore
            )
        } else {
            score = localized("activity.scoreUnavailable", state: state)
        }
        var value = String(
            format: localized("activity.accessibilityFormat", state: state),
            locale: locale(for: state),
            state.competitionName,
            state.homeTeamName,
            state.awayTeamName,
            score,
            context.state.statusText
        )
        if let minute = context.state.minute,
           context.state.fixtureState == WidgetMatchState.live.rawValue {
            value += ", \(minute)′"
        }
        if context.state.isDemo {
            value += ", \(localized("activity.demo", state: state))"
        }
        if context.isStale {
            value += ", \(localized("activity.stale", state: state))"
        }
        return Text(verbatim: value)
    }

    private func locale(for state: MatchActivityAttributes.ContentState) -> Locale {
        Locale(identifier: state.preferredLanguageCode == "en" ? "en" : "ar")
    }

    private func localized(
        _ key: String,
        state: MatchActivityAttributes.ContentState
    ) -> String {
        localizationBundle(for: state).localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }

    private func localizationBundle(
        for state: MatchActivityAttributes.ContentState
    ) -> Bundle {
        let code = state.preferredLanguageCode == "en" ? "en" : "ar"
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    private func deepLink(for fixtureID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "sportshub"
        components.host = "fixtures"
        components.path = "/\(fixtureID)"
        return components.url
    }
}
