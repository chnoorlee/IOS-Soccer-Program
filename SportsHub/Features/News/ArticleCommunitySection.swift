import SwiftUI

struct ArticleCommunitySection: View {
    @EnvironmentObject private var appModel: AppModel
    let articleID: String

    @State private var reactionSummary = ArticleReactionSummary.empty
    @State private var comments: [ArticleComment] = []
    @State private var nextCursor: String?
    @State private var loadedCursors: Set<String> = []
    @State private var hasMore = false
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var isMutatingReaction = false
    @State private var isSubmitting = false
    @State private var communityError: CommunityFailure?
    @State private var draft = ""
    @State private var submissionState: CommentModerationState?
    @State private var reportedCommentIDs: Set<String> = []
    @State private var reportingComment: ArticleComment?
    @State private var blockingComment: ArticleComment?
    @State private var isSafetyActionRunning = false
    @State private var loadRequestID: UUID?
    @AccessibilityFocusState private var noticeFocused: Bool

    private let pageLimit = 20
    private let maximumCommentLength = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            safetyCard
            reactionRail
            commentsRail
            composer
        }
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("article.community")
        .task(id: articleID) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationStateDidChange)) { _ in
            resetIdentityState()
            Task { await reload() }
        }
        .onChange(of: communityError) { _, error in
            focusNotice(error != nil)
        }
        .onChange(of: submissionState) { _, state in
            focusNotice(state != nil)
        }
        .confirmationDialog(
            "community.report.title",
            isPresented: Binding(
                get: { reportingComment != nil },
                set: { if !$0 { reportingComment = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(CommentReportReason.allCases) { reason in
                Button(LocalizedStringKey(reason.localizationKey)) {
                    guard let comment = reportingComment else { return }
                    reportingComment = nil
                    Task { await report(comment, reason: reason) }
                }
            }
            Button("common.cancel", role: .cancel) { reportingComment = nil }
        } message: {
            Text("community.report.explanation")
        }
        .alert(
            "community.block.title",
            isPresented: Binding(
                get: { blockingComment != nil },
                set: { if !$0 { blockingComment = nil } }
            ),
            presenting: blockingComment
        ) { comment in
            Button("community.block.confirm", role: .destructive) {
                blockingComment = nil
                Task { await block(comment) }
            }
            Button("common.cancel", role: .cancel) { blockingComment = nil }
        } message: { comment in
            Text(
                String(
                    format: NSLocalizedString("community.block.explanation", comment: ""),
                    comment.authorDisplayName
                )
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("community.title")
                    .font(.title2.weight(.black))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if appModel.usesDemoPublicData {
                    Text("community.demo")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.warm)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.warm.opacity(0.12), in: Capsule())
                }
            }
            Text("community.subtitle")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("community.safety.title", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text("community.safety.body")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)

            if appModel.communityConfiguration.standardsURL != nil
                || appModel.communityConfiguration.supportURL != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { safetyLinks }
                    VStack(alignment: .leading, spacing: 8) { safetyLinks }
                }
            }

            if !appModel.communityConfiguration.isReleaseGateSatisfied {
                Label("community.safety.developmentLocked", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warm)
                    .accessibilityIdentifier("community.releaseGate.locked")
            }
        }
        .sportsCard()
    }

    @ViewBuilder
    private var safetyLinks: some View {
        if let url = appModel.communityConfiguration.standardsURL {
            Link(destination: url) {
                Label("community.safety.standards", systemImage: "doc.text.fill")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("community.standards")
        }
        if let url = appModel.communityConfiguration.supportURL {
            Link(destination: url) {
                Label("community.safety.contact", systemImage: "envelope.fill")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("community.support")
        }
    }

    private var reactionRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("community.reactions.title")
                .font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { reactionButtons }
                VStack(alignment: .leading, spacing: 8) { reactionButtons }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
    }

    @ViewBuilder
    private var reactionButtons: some View {
        ForEach(ArticleReaction.allCases) { reaction in
            let selected = reactionSummary.myReaction == reaction
            Button {
                Task { await updateReaction(reaction) }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: reaction.systemImage)
                    Text(LocalizedStringKey(reaction.localizationKey))
                    Text(reactionSummary.total(for: reaction), format: .number)
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(selected ? AppTheme.accent : AppTheme.ink.opacity(0.72))
            .disabled(!mutationsAvailable || isMutatingReaction)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityHint(Text(mutationGateHintKey))
            .accessibilityIdentifier("community.reaction.\(reaction.rawValue.lowercased())")
        }
    }

    @ViewBuilder
    private var commentsRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("community.comments.title")
                .font(.headline)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("community.loading")
                }
                .frame(maxWidth: .infinity, minHeight: 64)
            } else if communityError == .load && comments.isEmpty {
                communityLoadFailure
            } else if comments.isEmpty {
                Label("community.empty", systemImage: "bubble.left.and.bubble.right")
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                    commentRow(comment, isLast: index == comments.count - 1)
                }
            }

            if communityError == .load && !comments.isEmpty {
                communityLoadFailure
            }

            if hasMore && communityError != .load {
                Button {
                    Task { await loadMore() }
                } label: {
                    if isLoadingMore {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("community.loadingMore")
                        }
                    } else {
                        Label("community.loadMore", systemImage: "arrow.down.circle")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.bordered)
                .disabled(isLoadingMore)
                .accessibilityIdentifier("community.comments.loadMore")
            }
        }
    }

    private var communityLoadFailure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                "community.error.load",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.warm)
            .accessibilityFocused($noticeFocused)
            Button {
                Task { await reload() }
            } label: {
                Label("action.retry", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("community.comments.retry")
        }
        .accessibilityIdentifier("community.error")
    }

    private func commentRow(_ comment: ArticleComment, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AppTheme.accent.opacity(0.18))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                if !isLast {
                    Rectangle()
                        .fill(AppTheme.accent.opacity(0.2))
                        .frame(width: 2)
                        .frame(minHeight: 58)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(comment.authorDisplayName)
                        .font(.subheadline.weight(.bold))
                    if comment.isMine {
                        Text("community.comment.you")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    Spacer()
                    Text(comment.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    if !comment.isMine && mutationsAvailable {
                        Menu {
                            Button {
                                reportingComment = comment
                            } label: {
                                Label("community.report.action", systemImage: "exclamationmark.bubble")
                            }
                            .disabled(reportedCommentIDs.contains(comment.id))
                            Button(role: .destructive) {
                                blockingComment = comment
                            } label: {
                                Label("community.block.action", systemImage: "hand.raised.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .disabled(isSafetyActionRunning)
                        .accessibilityLabel(Text("community.comment.actions"))
                        .accessibilityIdentifier("community.comment.actions.\(comment.id)")
                    }
                }
                Text(comment.body)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if reportedCommentIDs.contains(comment.id) {
                    Label("community.report.received", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("community.comment.\(comment.id)")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("community.composer.title")
                .font(.headline)
            if mutationsAvailable {
                Text("community.composer.label")
                    .font(.subheadline.weight(.semibold))
                TextEditor(text: $draft)
                    .frame(minHeight: 110)
                    .padding(8)
                    .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.muted.opacity(0.3), lineWidth: 1)
                    }
                    .accessibilityLabel(Text("community.composer.label"))
                    .accessibilityIdentifier("community.composer.body")
                    .onChange(of: draft) { _, value in
                        if value.count > maximumCommentLength {
                            draft = String(value.prefix(maximumCommentLength))
                        }
                    }
                HStack {
                    Text("community.composer.moderationNotice")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text("\(draft.count)/\(maximumCommentLength)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                        .accessibilityLabel(
                            Text(
                                String(
                                    format: NSLocalizedString("community.composer.countFormat", comment: ""),
                                    draft.count,
                                    maximumCommentLength
                                )
                            )
                        )
                }
                Button {
                    Task { await submitComment() }
                } label: {
                    if isSubmitting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("community.composer.submitting")
                        }
                    } else {
                        Label("community.composer.submit", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(normalizedDraft.isEmpty || isSubmitting)
                .accessibilityIdentifier("community.composer.submit")
            } else {
                Label(LocalizedStringKey(mutationGateMessageKey), systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .accessibilityIdentifier("community.composer.locked")
            }

            if let communityError, communityError != .load {
                Label(
                    LocalizedStringKey(communityError.localizationKey),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
                .accessibilityFocused($noticeFocused)
                .accessibilityIdentifier("community.error")
            } else if let submissionState {
                Label(
                    LocalizedStringKey(submissionKey(for: submissionState)),
                    systemImage: submissionState == .published
                        ? "checkmark.circle.fill"
                        : "clock.badge.checkmark.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(submissionState == .rejected ? AppTheme.warm : AppTheme.accent)
                .accessibilityFocused($noticeFocused)
                .accessibilityIdentifier("community.composer.receipt")
            }
        }
        .sportsCard()
    }

    private var mutationsAvailable: Bool {
        appModel.communityConfiguration.isReleaseGateSatisfied
            && appModel.authentication.status.user != nil
    }

    private var mutationGateMessageKey: String {
        if !appModel.communityConfiguration.isReleaseGateSatisfied {
            return "community.mutation.configurationRequired"
        }
        return "community.mutation.signInRequired"
    }

    private var mutationGateHintKey: LocalizedStringKey {
        if mutationsAvailable {
            return LocalizedStringKey("community.reactions.hint")
        }
        return LocalizedStringKey(mutationGateMessageKey)
    }

    private var normalizedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func reload() async {
        let requestID = UUID()
        loadRequestID = requestID
        isLoading = true
        communityError = nil
        reactionSummary = .empty
        comments = []
        nextCursor = nil
        loadedCursors = []
        hasMore = false
        async let reactionTask = appModel.dataProvider.articleReaction(articleID: articleID)
        async let commentsTask = appModel.dataProvider.articleComments(
            articleID: articleID,
            cursor: nil,
            limit: pageLimit
        )
        do {
            let (reaction, page) = try await (reactionTask, commentsTask)
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            reactionSummary = reaction
            comments = page.comments
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            communityError = .load
        }
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        isLoading = false
    }

    @MainActor
    private func loadMore() async {
        guard !isLoadingMore,
              hasMore,
              let cursor = nextCursor,
              !loadedCursors.contains(cursor),
              let requestID = loadRequestID else { return }
        let accountID = appModel.authentication.status.user?.id
        loadedCursors.insert(cursor)
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await appModel.dataProvider.articleComments(
                articleID: articleID,
                cursor: cursor,
                limit: pageLimit
            )
            guard loadRequestID == requestID,
                  appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            let existingIDs = Set(comments.map(\.id))
            guard page.comments.allSatisfy({ !existingIDs.contains($0.id) }) else {
                throw SportsDataError.contractViolation(field: "data.id")
            }
            if let previous = comments.last, let next = page.comments.first {
                guard previous.createdAt >= next.createdAt else {
                    throw SportsDataError.contractViolation(field: "data.createdAt")
                }
            }
            if let nextCursor = page.nextCursor {
                guard !loadedCursors.contains(nextCursor) else {
                    throw SportsDataError.contractViolation(field: "page.nextCursor")
                }
            }
            comments.append(contentsOf: page.comments)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            guard loadRequestID == requestID,
                  appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            communityError = .load
        }
    }

    @MainActor
    private func updateReaction(_ reaction: ArticleReaction) async {
        guard mutationsAvailable,
              !isMutatingReaction,
              let accountID = appModel.authentication.status.user?.id else { return }
        isMutatingReaction = true
        communityError = nil
        defer { isMutatingReaction = false }
        do {
            let desired: ArticleReaction? = reactionSummary.myReaction == reaction ? nil : reaction
            let confirmed = try await appModel.dataProvider.setArticleReaction(
                articleID: articleID,
                reaction: desired
            )
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            reactionSummary = confirmed
        } catch {
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            communityError = .mutation
        }
    }

    @MainActor
    private func submitComment() async {
        let body = normalizedDraft
        guard mutationsAvailable,
              !isSubmitting,
              (1...maximumCommentLength).contains(body.count),
              let accountID = appModel.authentication.status.user?.id else { return }
        isSubmitting = true
        submissionState = nil
        communityError = nil
        defer { isSubmitting = false }
        do {
            let comment = try await appModel.dataProvider.createArticleComment(
                articleID: articleID,
                body: body
            )
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            draft = ""
            submissionState = comment.moderationState
            if comment.moderationState == .published,
               !comments.contains(where: { $0.id == comment.id }) {
                comments.insert(comment, at: 0)
            }
        } catch let error as SportsDataError {
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            communityError = error == .contentRejected ? .rejected : .mutation
        } catch {
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            communityError = .mutation
        }
    }

    @MainActor
    private func report(_ comment: ArticleComment, reason: CommentReportReason) async {
        guard mutationsAvailable,
              !comment.isMine,
              !reportedCommentIDs.contains(comment.id),
              !isSafetyActionRunning,
              let accountID = appModel.authentication.status.user?.id else { return }
        isSafetyActionRunning = true
        communityError = nil
        defer { isSafetyActionRunning = false }
        do {
            _ = try await appModel.dataProvider.reportArticleComment(
                commentID: comment.id,
                reason: reason,
                details: nil
            )
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            reportedCommentIDs.insert(comment.id)
        } catch {
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            communityError = .safetyAction
        }
    }

    @MainActor
    private func block(_ comment: ArticleComment) async {
        guard mutationsAvailable,
              !comment.isMine,
              !isSafetyActionRunning,
              let accountID = appModel.authentication.status.user?.id else { return }
        isSafetyActionRunning = true
        communityError = nil
        defer { isSafetyActionRunning = false }
        do {
            try await appModel.dataProvider.blockCommunityAuthor(authorID: comment.authorID)
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            comments.removeAll { $0.authorID == comment.authorID }
        } catch {
            guard appModel.authentication.status.user?.id == accountID,
                  !Task.isCancelled else { return }
            communityError = .safetyAction
        }
    }

    @MainActor
    private func resetIdentityState() {
        loadRequestID = nil
        reactionSummary = .empty
        comments = []
        nextCursor = nil
        loadedCursors = []
        hasMore = false
        reportedCommentIDs = []
        draft = ""
        submissionState = nil
        communityError = nil
        reportingComment = nil
        blockingComment = nil
    }

    @MainActor
    private func focusNotice(_ shouldFocus: Bool) {
        guard shouldFocus else { return }
        noticeFocused = false
        Task { @MainActor in
            await Task.yield()
            noticeFocused = true
        }
    }

    private func submissionKey(for state: CommentModerationState) -> String {
        switch state {
        case .pending: "community.submission.pending"
        case .published: "community.submission.published"
        case .rejected: "community.submission.rejected"
        case .removed: "community.submission.removed"
        }
    }

    private enum CommunityFailure: Hashable {
        case load
        case mutation
        case rejected
        case safetyAction

        var localizationKey: String {
            switch self {
            case .load: "community.error.load"
            case .mutation: "community.error.mutation"
            case .rejected: "community.error.rejected"
            case .safetyAction: "community.error.safetyAction"
            }
        }
    }
}
