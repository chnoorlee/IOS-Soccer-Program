import SwiftUI
import WidgetKit

struct NextMatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMatchSnapshot?
    let isPlaceholder: Bool
    let loadFailed: Bool

    static func placeholder(at date: Date = Date()) -> NextMatchEntry {
        NextMatchEntry(
            date: date,
            snapshot: nil,
            isPlaceholder: true,
            loadFailed: false
        )
    }
}

struct NextMatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextMatchEntry {
        .placeholder()
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (NextMatchEntry) -> Void
    ) {
        completion(context.isPreview ? .placeholder() : entry(at: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<NextMatchEntry>) -> Void
    ) {
        let now = Date()
        let entry = entry(at: now)
        completion(Timeline(
            entries: [entry],
            policy: .after(nextRefresh(after: now, snapshot: entry.snapshot))
        ))
    }

    private func entry(at date: Date) -> NextMatchEntry {
        guard let identifier = Bundle.main.object(
            forInfoDictionaryKey: WidgetMatchContract.appGroupInfoKey
        ) as? String,
        let store = WidgetMatchSnapshotStore.appGroup(identifier: identifier) else {
            return NextMatchEntry(
                date: date,
                snapshot: nil,
                isPlaceholder: false,
                loadFailed: true
            )
        }

        do {
            return NextMatchEntry(
                date: date,
                snapshot: try store.read(),
                isPlaceholder: false,
                loadFailed: false
            )
        } catch {
            return NextMatchEntry(
                date: date,
                snapshot: nil,
                isPlaceholder: false,
                loadFailed: true
            )
        }
    }

    private func nextRefresh(
        after now: Date,
        snapshot: WidgetMatchSnapshot?
    ) -> Date {
        guard let snapshot else { return now.addingTimeInterval(30 * 60) }
        if snapshot.state.isLive {
            return now.addingTimeInterval(5 * 60)
        }
        if snapshot.state == .upcoming, snapshot.kickoff > now {
            return min(snapshot.kickoff, now.addingTimeInterval(30 * 60))
        }
        return now.addingTimeInterval(15 * 60)
    }
}

struct NextMatchWidget: Widget {
    let kind = WidgetMatchContract.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextMatchProvider()) { entry in
            NextMatchWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.05, green: 0.10, blue: 0.20)
                }
        }
        .configurationDisplayName("widget.nextMatch")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct NextMatchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextMatchEntry

    private var language: WidgetDisplayLanguage {
        entry.snapshot?.preferredLanguage ?? .arabic
    }

    var body: some View {
        Group {
            if entry.isPlaceholder {
                placeholder
                    .redacted(reason: .placeholder)
                    .accessibilityHidden(true)
            } else if let snapshot = entry.snapshot {
                ticket(snapshot)
                    .widgetURL(snapshot.deepLinkURL)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: snapshot))
                    .accessibilityHint(Text("widget.openHint"))
            } else {
                unavailable
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        Text(LocalizedStringKey(
                            entry.loadFailed ? "widget.loadFailed" : "widget.noMatch"
                        ))
                    )
                    .accessibilityHint(Text("widget.openHint"))
            }
        }
        .environment(\.locale, language.locale)
        .environment(
            \.layoutDirection,
            language == .arabic ? .rightToLeft : .leftToRight
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func ticket(_ snapshot: WidgetMatchSnapshot) -> some View {
        switch family {
        case .systemMedium:
            mediumTicket(snapshot)
        case .accessoryRectangular:
            accessoryTicket(snapshot)
        default:
            smallTicket(snapshot)
        }
    }

    private func mediumTicket(_ snapshot: WidgetMatchSnapshot) -> some View {
        VStack(spacing: 10) {
            ticketHeader(snapshot)
            HStack(alignment: .center, spacing: 12) {
                team(snapshot.homeTeamName(in: language))
                centerStatus(snapshot)
                    .frame(minWidth: 88)
                team(snapshot.awayTeamName(in: language))
            }
            if snapshot.isStale(at: entry.date) {
                staleLabel
            }
        }
    }

    private func smallTicket(_ snapshot: WidgetMatchSnapshot) -> some View {
        VStack(spacing: 7) {
            ticketHeader(snapshot)
            Text(snapshot.homeTeamName(in: language))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            centerStatus(snapshot)
            Text(snapshot.awayTeamName(in: language))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            if snapshot.isStale(at: entry.date) {
                staleLabel
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accessoryTicket(_ snapshot: WidgetMatchSnapshot) -> some View {
        HStack(spacing: 6) {
            Text(snapshot.homeTeamName(in: language))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            centerStatus(snapshot)
                .frame(minWidth: 54)
            Text(snapshot.awayTeamName(in: language))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
    }

    private func ticketHeader(_ snapshot: WidgetMatchSnapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sportscourt.fill")
                .foregroundStyle(Color(red: 0.16, green: 0.86, blue: 0.91))
                .accessibilityHidden(true)
            Text(snapshot.competitionName(in: language))
                .font(.caption.weight(.bold))
                .lineLimit(1)
            Spacer(minLength: 4)
            if snapshot.isDemo {
                Text("widget.demo")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
            }
        }
    }

    private func team(_ name: String) -> some View {
        Text(name)
            .font(.headline)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
    }

    private func centerStatus(_ snapshot: WidgetMatchSnapshot) -> some View {
        VStack(spacing: 3) {
            Text(LocalizedStringKey(snapshot.state.localizationKey))
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(red: 0.16, green: 0.86, blue: 0.91))
                .lineLimit(1)
            if let homeScore = snapshot.homeScore,
               let awayScore = snapshot.awayScore {
                Text("\(homeScore)–\(awayScore)")
                    .font(.title3.monospacedDigit().weight(.black))
                    .lineLimit(1)
            } else {
                Text(snapshot.kickoff, style: .time)
                    .font(.headline.monospacedDigit().weight(.black))
                    .lineLimit(1)
            }
            if let minute = snapshot.minute, snapshot.state == .live {
                Text("\(minute)′")
                    .font(.caption2.monospacedDigit().weight(.semibold))
            }
        }
    }

    private var staleLabel: some View {
        Label("widget.refreshRequired", systemImage: "arrow.clockwise.circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
            .lineLimit(1)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("widget.nextMatch", systemImage: "sportscourt.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.16, green: 0.86, blue: 0.91))
            Spacer(minLength: 0)
            Text(LocalizedStringKey(
                entry.loadFailed ? "widget.loadFailed" : "widget.noMatch"
            ))
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("widget.openApp")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("widget.nextMatch", systemImage: "sportscourt.fill")
                .font(.caption.weight(.bold))
            Spacer(minLength: 0)
            Text("widget.placeholder.home")
                .font(.headline)
            Text("widget.placeholder.away")
                .font(.headline)
            Text(Date(), style: .time)
                .font(.caption.monospacedDigit())
        }
    }

    private func accessibilityLabel(for snapshot: WidgetMatchSnapshot) -> Text {
        let status = localized(snapshot.state.localizationKey)
        let central: String
        if let homeScore = snapshot.homeScore,
           let awayScore = snapshot.awayScore {
            central = String(
                format: localized("widget.accessibility.scoreFormat"),
                locale: language.locale,
                homeScore,
                awayScore
            )
        } else {
            central = snapshot.kickoff.formatted(
                .dateTime.hour().minute().locale(language.locale)
            )
        }
        var value = String(
            format: localized("widget.accessibility.matchFormat"),
            locale: language.locale,
            snapshot.competitionName(in: language),
            snapshot.homeTeamName(in: language),
            snapshot.awayTeamName(in: language),
            central,
            status
        )
        if snapshot.isDemo {
            value += ", \(localized("widget.demo"))"
        }
        if snapshot.isStale(at: entry.date) {
            value += ", \(localized("widget.refreshRequired"))"
        }
        return Text(verbatim: value)
    }

    private func localized(_ key: String) -> String {
        localizationBundle.localizedString(forKey: key, value: key, table: nil)
    }

    private var localizationBundle: Bundle {
        guard let path = Bundle.main.path(
            forResource: language.rawValue,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
