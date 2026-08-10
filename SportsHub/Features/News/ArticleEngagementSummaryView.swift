import SwiftUI

struct ArticleEngagementSummaryView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let articleID: String
    let summary: ArticleEngagementSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    reactionMetric
                    commentMetric
                }
            } else {
                HStack(spacing: 18) {
                    reactionMetric
                    commentMetric
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("article.engagement.\(articleID)")
    }

    private var reactionMetric: some View {
        metric(
            text: localizedCount(
                "article.engagement.reactionsFormat",
                summary.totalReactions
            ),
            systemImage: "hand.thumbsup.fill",
            color: AppTheme.accent
        )
    }

    private var commentMetric: some View {
        metric(
            text: localizedCount(
                "article.engagement.commentsFormat",
                summary.publishedComments
            ),
            systemImage: "text.bubble.fill",
            color: AppTheme.warm
        )
    }

    private func metric(text: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(verbatim: text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }

    private func localizedCount(_ key: String.LocalizationValue, _ value: Int) -> String {
        let formattedValue = value.formatted(
            .number.locale(appModel.language.locale)
        )
        return String(
            format: String(localized: key, locale: appModel.language.locale),
            formattedValue
        )
    }
}
