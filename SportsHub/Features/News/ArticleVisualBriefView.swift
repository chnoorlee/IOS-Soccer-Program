import SwiftUI

struct ArticleFormatLabel: View {
    let format: ArticleFormat

    var body: some View {
        Label(LocalizedStringKey(format.localizationKey), systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                (format == .visualBrief ? AppTheme.warm : AppTheme.muted).opacity(0.14)
            )
            .clipShape(Capsule())
    }

    private var systemImage: String {
        switch format {
        case .story: "doc.text"
        case .visualBrief: "chart.bar.xaxis.ascending"
        }
    }
}

struct ArticleCardMetadataRow: View {
    let article: Article

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                badges
                Spacer(minLength: 8)
                publishedAt
            }

            VStack(alignment: .leading, spacing: 7) {
                badges
                publishedAt
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        StatusPill(text: LocalizedStringKey(article.categoryKey), color: AppTheme.accent)
        if article.format == .visualBrief {
            ArticleFormatLabel(format: article.format)
        }
    }

    private var publishedAt: some View {
        Text(article.publishedAt, style: .relative)
            .font(.caption)
            .foregroundStyle(AppTheme.muted)
    }
}

struct ArticleVisualBriefHero: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.ink, AppTheme.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(
                    Array([CGFloat(40), CGFloat(61), CGFloat(82)].enumerated()),
                    id: \.offset
                ) { _, height in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.white.opacity(0.9))
                        .frame(width: 32, height: height)
                }

                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(24)
        }
        .frame(minHeight: 180, idealHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("article.visual.heroDescription"))
        .accessibilityAddTraits(.isImage)
    }
}

struct ArticleVisualBriefView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let brief: ArticleVisualBrief

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label {
                Text("article.format.visualBrief")
            } icon: {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .foregroundStyle(AppTheme.warm)
            }
                .font(.caption.weight(.black))

            Text(brief.title(in: appModel.language))
                .font(.title2.weight(.black))
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)

            ForEach(brief.sections) { section in
                visualSection(section)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("article.visual.sourceNote")
                } icon: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
                    .font(.caption.weight(.bold))
                Text(brief.sourceNote(in: appModel.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.leading)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.12), AppTheme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule()
                .fill(AppTheme.warm)
                .frame(width: 5)
                .padding(.vertical, 22)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("article.visualBrief")
    }

    @ViewBuilder
    private func visualSection(_ section: ArticleVisualSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title(in: appModel.language))
                .font(.headline.weight(.black))
                .accessibilityAddTraits(.isHeader)

            switch section.kind {
            case .metricGrid:
                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                    ForEach(section.items) { item in
                        metricCard(item)
                    }
                }
            case .comparison:
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(section.items) { item in
                            comparisonCard(item)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(section.items) { item in
                            comparisonCard(item)
                        }
                    }
                }
            case .sequence:
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                        sequenceRow(item, index: index, isLast: index == section.items.count - 1)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("article.visual.section.\(section.id)")
    }

    private var metricColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 10, alignment: .topLeading)]
        }
        return [GridItem(.adaptive(minimum: 128), spacing: 10, alignment: .topLeading)]
    }

    private func metricCard(_ item: ArticleVisualItem) -> some View {
        visualItemContent(item)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(14)
            .background(AppTheme.background.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("article.visual.item.\(item.id)")
    }

    private func comparisonCard(_ item: ArticleVisualItem) -> some View {
        visualItemContent(item)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .padding(14)
            .background(AppTheme.ink.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(AppTheme.accent)
                    .frame(height: 4)
                    .padding(.horizontal, 14)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("article.visual.item.\(item.id)")
    }

    private func sequenceRow(
        _ item: ArticleVisualItem,
        index: Int,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(index + 1, format: .number)
                    .font(.caption.monospacedDigit().weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accent)
                    .clipShape(Circle())
                if !isLast {
                    Rectangle()
                        .fill(AppTheme.accent.opacity(0.35))
                        .frame(width: 3)
                        .frame(minHeight: 68, maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
            }
            visualItemContent(item)
                .padding(.bottom, isLast ? 0 : 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("article.visual.item.\(item.id)")
    }

    private func visualItemContent(_ item: ArticleVisualItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.value(in: appModel.language))
                .font(.title2.monospacedDigit().weight(.black))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
            Text(item.label(in: appModel.language))
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.leading)
            if let detail = item.detail(in: appModel.language) {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}
