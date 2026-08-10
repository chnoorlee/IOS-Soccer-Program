import SwiftUI

struct VideoProgramLibraryView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedSport: VideoSport?
    @State private var loadedSport: VideoSport?
    @State private var programs: [VideoProgramSummary] = []
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var freshness: PublicContentFreshness?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var loadFailed = false
    @State private var loadMoreFailed = false
    @State private var requestID: UUID?
    @AccessibilityFocusState private var errorFocused: Bool
    @AccessibilityFocusState private var freshnessFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                evidenceBoundary
                sportFilters

                if let freshness {
                    PublicContentStatusView(
                        freshness: freshness,
                        identifier: "video-programs"
                    )
                    .accessibilityFocused($freshnessFocused)
                }

                programContent
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("video.programs.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("video.programs.screen")
        .refreshable { await loadInitial(announceFreshness: true) }
        .task(id: selectedSport) { await loadInitial() }
    }

    private var evidenceBoundary: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "rectangle.stack.fill")
                .font(.title2.weight(.black))
                .foregroundStyle(AppTheme.warm)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("video.programs.boundaryTitle")
                    .font(.headline)
                Text("video.programs.boundaryBody")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.ink)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule()
                .fill(AppTheme.warm)
                .frame(width: 5)
                .padding(.vertical, 14)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("video.programs.boundary")
    }

    private var sportFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("video.programs.filterTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    sportFilter(nil, expands: true)
                    ForEach(VideoSport.allCases) { sport in
                        sportFilter(sport, expands: true)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        sportFilter(nil, expands: false)
                        ForEach(VideoSport.allCases) { sport in
                            sportFilter(sport, expands: false)
                        }
                    }
                }
                .accessibilityIdentifier("video.programs.filters.scroll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.programs.filters")
    }

    private func sportFilter(_ sport: VideoSport?, expands: Bool) -> some View {
        let isSelected = selectedSport == sport
        let identifier = sport?.rawValue ?? "all"
        return Button {
            selectedSport = sport
        } label: {
            Label(
                LocalizedStringKey(sport?.localizationKey ?? "video.programs.allSports"),
                systemImage: isSelected ? "checkmark.circle.fill" : sport?.systemImage ?? "square.grid.2x2.fill"
            )
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
        .accessibilityHint(Text("video.programs.filterHint"))
        .accessibilityIdentifier("video.programs.filter.\(identifier)")
    }

    @ViewBuilder
    private var programContent: some View {
        if isLoading && programs.isEmpty {
            LoadStateView(state: .loading)
                .accessibilityIdentifier("video.programs.loading")
        } else if loadFailed && programs.isEmpty {
            LoadStateView(state: .error) {
                Task { await loadInitial(announceFreshness: true) }
            }
            .accessibilityFocused($errorFocused)
            .accessibilityIdentifier("video.programs.error")
        } else if programs.isEmpty {
            ContentUnavailableView(
                "video.programs.emptyTitle",
                systemImage: "rectangle.stack",
                description: Text("video.programs.emptyBody")
            )
            .accessibilityIdentifier("video.programs.empty")
        } else {
            if loadFailed {
                inlineFailure(message: "video.programs.refreshFailed") {
                    Task { await loadInitial(announceFreshness: true) }
                }
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                ),
                spacing: 12
            ) {
                ForEach(programs) { program in
                    NavigationLink {
                        VideoProgramDetailView(summary: program)
                    } label: {
                        VideoProgramCard(program: program)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("video.program.card.\(program.id)")
                }
            }

            if hasMore {
                if loadMoreFailed {
                    inlineFailure(message: "video.programs.moreFailed") {
                        Task { await loadMore() }
                    }
                } else {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        if isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .accessibilityLabel(Text("common.loading"))
                        } else {
                            Label("video.programs.loadMore", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingMore)
                    .accessibilityIdentifier("video.program.loadMore")
                }
            }
        }
    }

    private func inlineFailure(
        message: LocalizedStringKey,
        retry: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            Spacer(minLength: 0)
            Button("video.programs.retry", action: retry)
                .font(.caption.weight(.bold))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(AppTheme.warm.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @MainActor
    private func loadInitial(announceFreshness: Bool = false) async {
        let activeSport = selectedSport
        let activeRequestID = UUID()
        requestID = activeRequestID
        if loadedSport != activeSport {
            programs = []
            nextCursor = nil
            hasMore = false
            freshness = nil
        }
        isLoading = true
        isLoadingMore = false
        loadFailed = false
        loadMoreFailed = false
        errorFocused = false

        do {
            let page = try await appModel.dataProvider.videoPrograms(
                cursor: nil,
                limit: VideoProgramPaginationContract.maximumPageSize,
                sport: activeSport
            )
            guard requestID == activeRequestID,
                  selectedSport == activeSport,
                  !Task.isCancelled else { return }
            programs = page.programs
            nextCursor = page.nextCursor
            hasMore = page.hasMore
            loadedSport = activeSport
            freshness = await appModel.publicContentFreshness(for: .videoPrograms(sport: activeSport))
            guard requestID == activeRequestID,
                  selectedSport == activeSport,
                  !Task.isCancelled else { return }
            isLoading = false
            if announceFreshness || freshness?.requiresAttention == true {
                freshnessFocused = false
                await Task.yield()
                freshnessFocused = freshness != nil
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestID == activeRequestID,
                  selectedSport == activeSport else { return }
            freshness = await appModel.publicContentFreshness(for: .videoPrograms(sport: activeSport))
            isLoading = false
            loadFailed = true
            if programs.isEmpty {
                errorFocused = true
            }
        }
    }

    @MainActor
    private func loadMore() async {
        guard !isLoadingMore, let cursor = nextCursor else { return }
        let activeSport = selectedSport
        let activeRequestID = requestID
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await appModel.dataProvider.videoPrograms(
                cursor: cursor,
                limit: VideoProgramPaginationContract.maximumPageSize,
                sport: activeSport
            )
            guard requestID == activeRequestID,
                  selectedSport == activeSport,
                  !Task.isCancelled else { return }
            programs = try page.appending(to: programs)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
            freshness = await appModel.publicContentFreshness(for: .videoPrograms(sport: activeSport))
            guard requestID == activeRequestID,
                  selectedSport == activeSport,
                  !Task.isCancelled else { return }
            isLoadingMore = false
        } catch is CancellationError {
            return
        } catch {
            guard requestID == activeRequestID,
                  selectedSport == activeSport else { return }
            freshness = await appModel.publicContentFreshness(for: .videoPrograms(sport: activeSport))
            isLoadingMore = false
            loadMoreFailed = true
        }
    }
}

struct VideoProgramDetailView: View {
    @EnvironmentObject private var appModel: AppModel

    let programID: String
    let previewSummary: VideoProgramSummary?
    let previewProgram: VideoProgram?

    @State private var loadedProgram: VideoProgramSummary?
    @State private var loadedProgramID: String?
    @State private var episodes: [VideoProgramEpisode] = []
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var freshness: PublicContentFreshness?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasLoaded = false
    @State private var loadFailed = false
    @State private var loadMoreFailed = false
    @State private var requestID: UUID?
    @AccessibilityFocusState private var errorFocused: Bool
    @AccessibilityFocusState private var freshnessFocused: Bool

    init(summary: VideoProgramSummary) {
        programID = summary.id
        previewSummary = summary
        previewProgram = summary.program
    }

    init(programID: String, previewProgram: VideoProgram? = nil) {
        self.programID = programID
        previewSummary = nil
        self.previewProgram = previewProgram
    }

    private var program: VideoProgramSummary? {
        if loadedProgramID == programID, let loadedProgram {
            return loadedProgram
        }
        return previewSummary
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let program {
                    VideoProgramHeader(program: program)
                }

                if let freshness {
                    PublicContentStatusView(
                        freshness: freshness,
                        identifier: "video-program-\(programID)"
                    )
                    .accessibilityFocused($freshnessFocused)
                }

                detailContent
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("video.program.detail")
        .refreshable { await loadInitial(announceFreshness: true) }
        .task(id: programID) { await loadInitial() }
    }

    private var navigationTitle: String {
        if let program {
            return program.title(in: appModel.language)
        }
        if let previewProgram {
            return previewProgram.title(in: appModel.language)
        }
        return String(localized: "video.programs.title", locale: appModel.language.locale)
    }

    @ViewBuilder
    private var detailContent: some View {
        if isLoading && !hasLoaded {
            LoadStateView(state: .loading)
                .accessibilityIdentifier("video.program.detail.loading")
        } else if loadFailed && !hasLoaded {
            LoadStateView(state: .error) {
                Task { await loadInitial(announceFreshness: true) }
            }
            .accessibilityFocused($errorFocused)
            .accessibilityIdentifier("video.program.detail.error")
        } else {
            if loadFailed {
                inlineFailure(message: "video.programs.refreshFailed") {
                    Task { await loadInitial(announceFreshness: true) }
                }
            }

            SectionHeader(title: "video.programs.episodes")

            if episodes.isEmpty {
                ContentUnavailableView(
                    "video.programs.noEpisodesTitle",
                    systemImage: "play.rectangle",
                    description: Text("video.programs.noEpisodesBody")
                )
                .accessibilityIdentifier("video.program.detail.empty")
            } else {
                ForEach(episodes) { episode in
                    NavigationLink {
                        VideoDetailView(video: episode.video)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            if let publishedAt = episode.publishedAt {
                                Label {
                                    Text(publishedAt, format: .dateTime.day().month().year())
                                } icon: {
                                    Image(systemName: "calendar")
                                        .accessibilityHidden(true)
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.muted)
                            }
                            VideoCard(video: episode.video)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("video.programs.openHint"))
                    .accessibilityIdentifier("video.program.episode.\(episode.id)")
                }
            }

            if hasMore {
                if loadMoreFailed {
                    inlineFailure(message: "video.programs.moreFailed") {
                        Task { await loadMore() }
                    }
                } else {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        if isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .accessibilityLabel(Text("common.loading"))
                        } else {
                            Label("video.programs.loadMore", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingMore)
                    .accessibilityIdentifier("video.program.detail.loadMore")
                }
            }
        }
    }

    private func inlineFailure(
        message: LocalizedStringKey,
        retry: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            Spacer(minLength: 0)
            Button("video.programs.retry", action: retry)
                .font(.caption.weight(.bold))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(AppTheme.warm.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @MainActor
    private func loadInitial(announceFreshness: Bool = false) async {
        let activeRequestID = UUID()
        requestID = activeRequestID
        if loadedProgramID != programID {
            loadedProgram = nil
            episodes = []
            nextCursor = nil
            hasMore = false
            freshness = nil
            hasLoaded = false
        }
        isLoading = true
        isLoadingMore = false
        loadFailed = false
        loadMoreFailed = false
        errorFocused = false

        do {
            let page = try await appModel.dataProvider.videoProgramDetails(
                id: programID,
                cursor: nil,
                limit: VideoProgramPaginationContract.maximumPageSize
            )
            guard requestID == activeRequestID, !Task.isCancelled else { return }
            loadedProgram = page.program
            loadedProgramID = programID
            episodes = page.episodes
            nextCursor = page.nextCursor
            hasMore = page.hasMore
            hasLoaded = true
            freshness = await appModel.publicContentFreshness(for: .videoProgram(id: programID))
            guard requestID == activeRequestID, !Task.isCancelled else { return }
            isLoading = false
            if announceFreshness || freshness?.requiresAttention == true {
                freshnessFocused = false
                await Task.yield()
                freshnessFocused = freshness != nil
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestID == activeRequestID else { return }
            freshness = await appModel.publicContentFreshness(for: .videoProgram(id: programID))
            isLoading = false
            loadFailed = true
            if !hasLoaded {
                errorFocused = true
            }
        }
    }

    @MainActor
    private func loadMore() async {
        guard !isLoadingMore, let cursor = nextCursor else { return }
        let activeRequestID = requestID
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await appModel.dataProvider.videoProgramDetails(
                id: programID,
                cursor: cursor,
                limit: VideoProgramPaginationContract.maximumPageSize
            )
            guard requestID == activeRequestID, !Task.isCancelled else { return }
            guard page.program.id == loadedProgram?.id else {
                throw SportsDataError.contractViolation(field: "data.program.id")
            }
            episodes = try page.appendingEpisodes(to: episodes)
            loadedProgram = page.program
            nextCursor = page.nextCursor
            hasMore = page.hasMore
            freshness = await appModel.publicContentFreshness(for: .videoProgram(id: programID))
            guard requestID == activeRequestID, !Task.isCancelled else { return }
            isLoadingMore = false
        } catch is CancellationError {
            return
        } catch {
            guard requestID == activeRequestID else { return }
            freshness = await appModel.publicContentFreshness(for: .videoProgram(id: programID))
            isLoadingMore = false
            loadMoreFailed = true
        }
    }
}

private struct VideoProgramCard: View {
    @EnvironmentObject private var appModel: AppModel
    let program: VideoProgramSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VideoProgramArtwork(program: program)

            Label(
                LocalizedStringKey(program.sport.localizationKey),
                systemImage: program.sport.systemImage
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(programAccent(program.sport))

            Text(program.title(in: appModel.language))
                .font(.title3.weight(.black))
                .multilineTextAlignment(.leading)

            Text(program.description(in: appModel.language))
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(4)
                .multilineTextAlignment(.leading)

            if program.featuredVideo != nil {
                Label("video.programs.featured", systemImage: "play.rectangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.warm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .overlay(alignment: .leading) {
            Capsule()
                .fill(programAccent(program.sport))
                .frame(width: 5)
                .padding(.vertical, 14)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("video.programs.openHint"))
    }
}

private struct VideoProgramHeader: View {
    @EnvironmentObject private var appModel: AppModel
    let program: VideoProgramSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VideoProgramArtwork(program: program)

            Label(
                LocalizedStringKey(program.sport.localizationKey),
                systemImage: program.sport.systemImage
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(programAccent(program.sport))

            Text(program.title(in: appModel.language))
                .font(.largeTitle.weight(.black))
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)

            Text(program.description(in: appModel.language))
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.program.header")
    }
}

private struct VideoProgramArtwork: View {
    let program: VideoProgramSummary

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let featuredVideo = program.featuredVideo {
                VideoPosterMediaView(video: featuredVideo, presentation: .card)
                    .accessibilityHidden(true)
            } else {
                LinearGradient(
                    colors: [AppTheme.ink, programAccent(program.sport).opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    Image(systemName: program.sport.systemImage)
                        .font(.system(size: 46, weight: .black))
                        .foregroundStyle(.white.opacity(0.26))
                        .accessibilityHidden(true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == 0 ? programAccent(program.sport) : Color.white.opacity(0.72))
                        .frame(width: index == 0 ? 30 : 12, height: 4)
                }
            }
            .padding(12)
            .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }
}

private func programAccent(_ sport: VideoSport) -> Color {
    switch sport {
    case .football: AppTheme.accent
    case .basketball: .orange
    case .esports: .purple
    case .motorsport: AppTheme.live
    case .combat: AppTheme.warm
    case .archery: .teal
    }
}
