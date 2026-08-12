import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private struct FollowSyncOperation {
        let id: UUID
        let accountID: String?
        let task: Task<Void, Never>
    }

    private struct FollowMutationOperation {
        let id: UUID
        let accountID: String?
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            widgetMatchSnapshotCoordinator.updateLanguage(language)
        }
    }

    @Published private(set) var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    @Published private(set) var orderedFollows: [SportsFollow] {
        didSet {
            widgetMatchSnapshotCoordinator.updateFollows(orderedFollows)
            guard followStateIdentityKey == "guest",
                  authentication.status != .loading,
                  authentication.status.user == nil else {
                return
            }
            let followedTeamIDs = orderedFollows
                .filter { $0.type == .team }
                .map(\.entityID)
            if followedTeamIDs.isEmpty {
                defaults.removeObject(forKey: GuestPersonalizationDefaults.followedTeamIDs)
            } else {
                defaults.set(
                    followedTeamIDs,
                    forKey: GuestPersonalizationDefaults.followedTeamIDs
                )
            }
        }
    }

    @Published private(set) var followMutationKeys: Set<String> = []
    @Published private(set) var isSynchronizingFollows = false
    @Published private(set) var followError: SportsDataError?
    @Published private(set) var publicCacheSummary = SportsDataCacheSummary.empty()
    @Published private(set) var isPublicCacheBusy = false
    @Published private(set) var publicCacheError: SportsDataError?

    let dataProvider: any SportsDataProviding
    let authentication: AuthenticationManager
    let subscriptionStore: PremiumSubscriptionModel
    let publicCache: any SportsDataCacheManaging
    let publicContentFreshnessStore: any PublicContentFreshnessReading
    let usesDemoPublicData: Bool
    let communityConfiguration: CommunityConfiguration
    let notificationSettings: NotificationSettingsModel
    let playbackDeviceID: String
    let notificationInstallationID: String
    let playbackCapabilities = PlaybackCapabilities.nativeHLS
    let widgetMatchSnapshotCoordinator: WidgetMatchSnapshotCoordinator
    let matchLiveActivityCoordinator: MatchLiveActivityCoordinator

    private let defaults: UserDefaults
    private let resetsFollowsOnLaunch: Bool
    private var didApplyLaunchFollowReset = false
    private var didPrepareUITestHistory = false
    private var followSyncOperation: FollowSyncOperation?
    private var followMutationOperations: [String: FollowMutationOperation] = [:]
    private var followStateIdentityKey = "guest"

    var followedTeamIDs: Set<String> {
        followedEntityIDs(of: .team)
    }

    var followedPlayerIDs: Set<String> {
        followedEntityIDs(of: .player)
    }

    var followedCompetitionIDs: Set<String> {
        followedEntityIDs(of: .competition)
    }

    var hasFollowedInterests: Bool {
        !orderedFollows.isEmpty
    }

    init(
        services: AppServices = AppEnvironment.makeServices(),
        defaults: UserDefaults = .standard,
        widgetMatchSnapshotCoordinator: WidgetMatchSnapshotCoordinator = .system(),
        matchLiveActivityCoordinator: MatchLiveActivityCoordinator = .system()
    ) {
        dataProvider = services.dataProvider
        authentication = services.authentication
        subscriptionStore = services.subscriptionStore
        publicCache = services.publicCache
        publicContentFreshnessStore = services.publicContentFreshness
        usesDemoPublicData = services.usesDemoPublicData
        communityConfiguration = services.communityConfiguration
        self.defaults = defaults
        self.widgetMatchSnapshotCoordinator = widgetMatchSnapshotCoordinator
        self.matchLiveActivityCoordinator = matchLiveActivityCoordinator

        let resetRequested = ProcessInfo.processInfo.arguments.contains("-reset-onboarding")
        resetsFollowsOnLaunch = resetRequested
        let storedLanguage = defaults.string(forKey: Keys.language)
        let storedPlaybackDeviceID = defaults.string(forKey: Keys.playbackDeviceID)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedPlaybackDeviceID, (16...128).contains(storedPlaybackDeviceID.count) {
            playbackDeviceID = storedPlaybackDeviceID
        } else {
            let generatedPlaybackDeviceID = UUID().uuidString.lowercased()
            playbackDeviceID = generatedPlaybackDeviceID
            defaults.set(generatedPlaybackDeviceID, forKey: Keys.playbackDeviceID)
        }
        let storedNotificationInstallationID = defaults.string(
            forKey: Keys.notificationInstallationID
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedNotificationInstallationID,
           (16...128).contains(storedNotificationInstallationID.count) {
            notificationInstallationID = storedNotificationInstallationID
        } else {
            let generatedNotificationInstallationID = UUID().uuidString.lowercased()
            notificationInstallationID = generatedNotificationInstallationID
            defaults.set(
                generatedNotificationInstallationID,
                forKey: Keys.notificationInstallationID
            )
        }
        let authentication = services.authentication
        notificationSettings = NotificationSettingsModel(
            dataProvider: services.dataProvider,
            permissionCoordinator: services.notificationPermissions,
            installationID: notificationInstallationID,
            environment: Self.pushNotificationEnvironment,
            currentAccountID: { [weak authentication] in
                authentication?.status.user?.id
            }
        )
        language = AppLanguage(rawValue: storedLanguage ?? "") ?? .arabic
        hasCompletedOnboarding = resetRequested ? false : defaults.bool(forKey: Keys.onboarding)
        let legacyTeamIDs = resetRequested
            ? []
            : defaults.stringArray(
                forKey: GuestPersonalizationDefaults.followedTeamIDs
            ) ?? []
        let normalizedLegacyTeamIDs = Array(
            Set(legacyTeamIDs)
                .filter { Self.isValidFollowIdentifier($0) }
                .sorted()
                .prefix(500)
        )
        orderedFollows = normalizedLegacyTeamIDs.map { teamID in
            SportsFollow(
                id: "legacy:TEAM:\(teamID)",
                type: .team,
                entityID: teamID,
                createdAt: .distantPast
            )
        }.canonicalFollowOrder
        if !resetRequested, normalizedLegacyTeamIDs != legacyTeamIDs {
            defaults.set(
                normalizedLegacyTeamIDs,
                forKey: GuestPersonalizationDefaults.followedTeamIDs
            )
        }
        widgetMatchSnapshotCoordinator.updateLanguage(language)
        widgetMatchSnapshotCoordinator.updateFollows(orderedFollows)
    }

    @discardableResult
    func publishWidgetFixtures(
        _ fixtures: [Fixture],
        isDemo: Bool
    ) -> WidgetMatchSnapshotPublishResult {
        widgetMatchSnapshotCoordinator.publish(
            fixtures: fixtures,
            follows: orderedFollows,
            language: language,
            isDemo: isDemo
        )
    }

    @discardableResult
    func clearWidgetMatchSnapshot() -> WidgetMatchSnapshotPublishResult {
        widgetMatchSnapshotCoordinator.clear()
    }

    convenience init(
        dataProvider: any SportsDataProviding,
        defaults: UserDefaults = .standard
    ) {
        self.init(
            services: AppServices(
                dataProvider: dataProvider,
                authentication: AppEnvironment.makeUnavailableAuthenticationManager(),
                notificationPermissions: UnavailableNotificationPermissionCoordinator()
            ),
            defaults: defaults
        )
    }

    func toggleFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?
    ) {
        let entityID = entityID.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountID = authentication.status.user?.id
        prepareFollowState(for: accountID)
        guard Self.isValidFollowIdentifier(entityID),
              entity == nil || (entity?.type == type && entity?.entityID == entityID),
              !isSynchronizingFollows else {
            return
        }
        let targetKey = Self.followTargetKey(type: type, entityID: entityID)
        guard !followMutationKeys.contains(targetKey) else { return }

        let previousFollow = orderedFollows.first {
            $0.type == type && $0.entityID == entityID
        }
        let shouldFollow = previousFollow == nil
        guard !shouldFollow || entity != nil else {
            followError = .contractViolation(field: "entity")
            return
        }
        guard previousFollow != nil || orderedFollows.count < 500 else {
            followError = .contractViolation(field: "follows")
            return
        }
        followError = nil
        if previousFollow != nil {
            removeFollow(type: type, entityID: entityID)
        } else {
            replaceFollow(SportsFollow(
                id: "pending:\(UUID().uuidString.lowercased())",
                type: type,
                entityID: entityID,
                createdAt: Date(),
                entity: entity
            ))
        }
        let operationID = UUID()
        followMutationOperations[targetKey] = FollowMutationOperation(
            id: operationID,
            accountID: accountID
        )
        followMutationKeys.insert(targetKey)

        Task { [weak self] in
            guard let self else { return }
            guard isCurrentFollowIdentity(accountID),
                  isCurrentFollowMutation(
                      targetKey: targetKey,
                      operationID: operationID,
                      accountID: accountID
                  ) else {
                finishFollowMutation(targetKey: targetKey, operationID: operationID)
                await synchronizeFollows()
                return
            }
            do {
                let result = try await setFollow(
                    type: type,
                    entityID: entityID,
                    entity: entity,
                    isFollowing: shouldFollow,
                    for: accountID
                )
                guard isCurrentFollowIdentity(accountID),
                      isCurrentFollowMutation(
                          targetKey: targetKey,
                          operationID: operationID,
                          accountID: accountID
                      ),
                      !Task.isCancelled else {
                    finishFollowMutation(targetKey: targetKey, operationID: operationID)
                    await synchronizeFollows()
                    return
                }
                if shouldFollow {
                    guard let result,
                          result.type == type,
                          result.entityID == entityID,
                          result.entity != nil,
                          result.hasMatchingEntitySnapshot,
                          Self.isValidFollowIdentifier(result.id, maximumLength: 160),
                          result.createdAt <= Date().addingTimeInterval(5 * 60),
                          !orderedFollows.contains(where: {
                              $0.id == result.id
                                  && ($0.type != type || $0.entityID != entityID)
                          }) else {
                        throw SportsDataError.contractViolation(field: "follow")
                    }
                    replaceFollow(result)
                } else {
                    guard result == nil else {
                        throw SportsDataError.contractViolation(field: "follow")
                    }
                    removeFollow(type: type, entityID: entityID)
                }
                followError = nil
                NotificationCenter.default.post(name: .followsDidChange, object: nil)
            } catch {
                if isCurrentFollowIdentity(accountID),
                   isCurrentFollowMutation(
                       targetKey: targetKey,
                       operationID: operationID,
                       accountID: accountID
                   ),
                   !Task.isCancelled {
                    if let previousFollow {
                        replaceFollow(previousFollow)
                    } else {
                        removeFollow(type: type, entityID: entityID)
                    }
                    followError = SportsDataError.normalized(error)
                }
            }
            finishFollowMutation(targetKey: targetKey, operationID: operationID)
            if !isCurrentFollowIdentity(accountID) {
                await synchronizeFollows()
            }
        }
    }

    func synchronizeFollows() async {
        let accountID = authentication.status.user?.id
        prepareFollowState(for: accountID)
        if let operation = followSyncOperation {
            if operation.accountID == accountID {
                await operation.task.value
                return
            }
            operation.task.cancel()
            followSyncOperation = nil
        }
        let operationID = UUID()
        isSynchronizingFollows = true
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await performFollowSynchronization(accountID: accountID)
        }
        followSyncOperation = FollowSyncOperation(
            id: operationID,
            accountID: accountID,
            task: task
        )
        await task.value
        if followSyncOperation?.id == operationID {
            followSyncOperation = nil
            isSynchronizingFollows = false
        }
    }

    private func performFollowSynchronization(accountID: String?) async {
        guard followMutationKeys.isEmpty,
              isCurrentFollowIdentity(accountID),
              !Task.isCancelled else {
            return
        }
        do {
            var follows = try await self.follows(for: accountID)
            guard isCurrentFollowIdentity(accountID), !Task.isCancelled else { return }
            if resetsFollowsOnLaunch, !didApplyLaunchFollowReset {
                for follow in follows {
                    _ = try await setFollow(
                        type: follow.type,
                        entityID: follow.entityID,
                        entity: follow.entity,
                        isFollowing: false,
                        for: accountID
                    )
                    guard isCurrentFollowIdentity(accountID), !Task.isCancelled else { return }
                }
                defaults.removeObject(forKey: GuestPersonalizationDefaults.followedTeamIDs)
                orderedFollows = []
                follows = []
                didApplyLaunchFollowReset = true
            }
            let isGuest = accountID == nil
            let legacyGuestTeamIDs = Set(
                defaults.stringArray(
                    forKey: GuestPersonalizationDefaults.followedTeamIDs
                ) ?? []
            )
            if isGuest, follows.isEmpty, !legacyGuestTeamIDs.isEmpty {
                let teams = (try? await dataProvider.teams()) ?? []
                let teamsByID = teams.reduce(into: [String: Team]()) {
                    $0[$1.id] = $1
                }
                for teamID in legacyGuestTeamIDs.sorted() {
                    _ = try await setFollow(
                        type: .team,
                        entityID: teamID,
                        entity: teamsByID[teamID].map { .team($0) },
                        isFollowing: true,
                        for: accountID
                    )
                    guard isCurrentFollowIdentity(accountID), !Task.isCancelled else { return }
                }
                follows = try await self.follows(for: accountID)
                guard isCurrentFollowIdentity(accountID), !Task.isCancelled else { return }
            }
            orderedFollows = try Self.validatedFollows(follows)
            followError = nil
            NotificationCenter.default.post(name: .followsDidChange, object: nil)
        } catch {
            guard isCurrentFollowIdentity(accountID), !Task.isCancelled else { return }
            followError = SportsDataError.normalized(error)
        }
    }

    private func isCurrentFollowIdentity(_ accountID: String?) -> Bool {
        authentication.status.user?.id == accountID
    }

    @discardableResult
    func clearDeviceGuestPersonalization() async -> Bool {
        guard !authentication.isBusy,
              !isFollowActivityInProgress else {
            return false
        }
        let wasGuest = authentication.status.user == nil
        let cleared = await authentication.clearDeviceGuestPersonalization()
        guard cleared else { return false }

        if wasGuest, authentication.status.user == nil {
            orderedFollows = []
        }
        followError = nil
        NotificationCenter.default.post(name: .watchProgressDidChange, object: nil)
        NotificationCenter.default.post(name: .videoFavoritesDidChange, object: nil)
        NotificationCenter.default.post(name: .articleFavoritesDidChange, object: nil)
        NotificationCenter.default.post(name: .followsDidChange, object: nil)
        return true
    }

    func isFollowMutationInProgress(teamID: String) -> Bool {
        isFollowMutationInProgress(type: .team, entityID: teamID)
    }

    func isFollowMutationInProgress(
        type: FollowEntityType,
        entityID: String
    ) -> Bool {
        isSynchronizingFollows || followMutationKeys.contains(
            Self.followTargetKey(type: type, entityID: entityID)
        )
    }

    func isFollowing(type: FollowEntityType, entityID: String) -> Bool {
        orderedFollows.contains { $0.type == type && $0.entityID == entityID }
    }

    var isFollowActivityInProgress: Bool {
        isSynchronizingFollows || !followMutationKeys.isEmpty
    }

    func dismissFollowError() {
        followError = nil
    }

    @discardableResult
    func refreshPublicCacheSummary() async -> Bool {
        guard !isPublicCacheBusy else { return false }
        isPublicCacheBusy = true
        defer { isPublicCacheBusy = false }
        do {
            publicCacheSummary = try await publicCache.cacheSummary()
            publicCacheError = nil
            return true
        } catch {
            publicCacheError = .localStorageUnavailable
            return false
        }
    }

    @discardableResult
    func clearPublicCache() async -> Bool {
        guard !isPublicCacheBusy else { return false }
        isPublicCacheBusy = true
        defer { isPublicCacheBusy = false }
        do {
            try await publicCache.clearCache()
            publicCacheSummary = .empty(
                maximumByteCount: publicCacheSummary.maximumByteCount
            )
            publicCacheError = nil
            return true
        } catch {
            publicCacheError = .localStorageUnavailable
            return false
        }
    }

    func publicContentFreshness(
        for resource: PublicContentResource
    ) async -> PublicContentFreshness? {
        if usesDemoPublicData {
            return .demo
        }
        return await publicContentFreshnessStore.status(for: resource)
    }

    func completeOnboarding() {
        guard hasFollowedInterests, !isFollowActivityInProgress else { return }
        hasCompletedOnboarding = true
    }

    func skipOnboarding() {
        guard !isFollowActivityInProgress else { return }
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }

    func prepareUITestHistoryIfRequested() async {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let shouldReset = arguments.contains("-ui-test-reset-history")
        let shouldSeed = arguments.contains("-ui-test-seed-history")
        guard !didPrepareUITestHistory, shouldReset || shouldSeed else { return }
        didPrepareUITestHistory = true
        let configuredMode = Bundle.main.object(
            forInfoDictionaryKey: "SportsDataMode"
        ) as? String
        guard authentication.status == .unavailable,
              configuredMode == SportsDataMode.mock.rawValue else {
            assertionFailure("UI test history fixtures require the mock, signed-out build")
            return
        }

        do {
            try await dataProvider.clearWatchHistory()
            guard shouldSeed else { return }
            _ = try await dataProvider.setVideoFavorite(
                videoID: "video-highlight-1",
                isFavorite: true
            )
            _ = try await dataProvider.saveWatchProgress(
                videoID: "video-highlight-1",
                positionSeconds: 125,
                completed: false
            )
            _ = try await dataProvider.saveWatchProgress(
                videoID: "video-original-1",
                positionSeconds: 180,
                completed: true
            )
        } catch {
            assertionFailure("UI test history fixture could not be prepared")
        }
        #endif
    }

    private enum Keys {
        static let language = "app.language"
        static let onboarding = "app.onboarding.completed"
        static let playbackDeviceID = "app.playback.deviceID"
        static let notificationInstallationID = "app.notification.installationID"
    }

    private static var pushNotificationEnvironment: PushNotificationEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }

    private func followedEntityIDs(of type: FollowEntityType) -> Set<String> {
        Set(orderedFollows.lazy.filter { $0.type == type }.map(\.entityID))
    }

    private func follows(for accountID: String?) async throws -> [SportsFollow] {
        if let scopedProvider = dataProvider as? any IdentityScopedFollowProviding {
            return try await scopedProvider.follows(forAccountID: accountID)
        }
        guard accountID == nil else { throw SportsDataError.unauthorized }
        return try await dataProvider.follows()
    }

    private func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool,
        for accountID: String?
    ) async throws -> SportsFollow? {
        if let scopedProvider = dataProvider as? any IdentityScopedFollowProviding {
            return try await scopedProvider.setFollow(
                type: type,
                entityID: entityID,
                entity: entity,
                isFollowing: isFollowing,
                forAccountID: accountID
            )
        }
        guard accountID == nil else { throw SportsDataError.unauthorized }
        return try await dataProvider.setFollow(
            type: type,
            entityID: entityID,
            entity: entity,
            isFollowing: isFollowing
        )
    }

    private func replaceFollow(_ follow: SportsFollow) {
        var nextFollows = orderedFollows
        nextFollows.removeAll {
            $0.type == follow.type && $0.entityID == follow.entityID
        }
        nextFollows.append(follow)
        orderedFollows = nextFollows.canonicalFollowOrder
    }

    private func removeFollow(type: FollowEntityType, entityID: String) {
        orderedFollows.removeAll { $0.type == type && $0.entityID == entityID }
    }

    private func finishFollowMutation(targetKey: String, operationID: UUID) {
        guard followMutationOperations[targetKey]?.id == operationID else { return }
        followMutationOperations[targetKey] = nil
        followMutationKeys.remove(targetKey)
    }

    private func isCurrentFollowMutation(
        targetKey: String,
        operationID: UUID,
        accountID: String?
    ) -> Bool {
        guard let operation = followMutationOperations[targetKey] else { return false }
        return operation.id == operationID && operation.accountID == accountID
    }

    private func prepareFollowState(for accountID: String?) {
        let identityKey = Self.followIdentityKey(accountID: accountID)
        guard followStateIdentityKey != identityKey else { return }
        // Clear while the old identity key is still active. This prevents an
        // account-to-guest transition from deleting legacy guest migration data.
        widgetMatchSnapshotCoordinator.clear()
        orderedFollows = []
        followError = nil
        followStateIdentityKey = identityKey

        let staleTargets = followMutationOperations.compactMap { targetKey, operation in
            operation.accountID == accountID ? nil : targetKey
        }
        for targetKey in staleTargets {
            followMutationOperations[targetKey] = nil
            followMutationKeys.remove(targetKey)
        }
    }

    private static func validatedFollows(_ follows: [SportsFollow]) throws -> [SportsFollow] {
        guard follows.count <= 500 else {
            throw SportsDataError.contractViolation(field: "follows")
        }
        let maximumCreatedAt = Date().addingTimeInterval(5 * 60)
        var followIDs = Set<String>()
        var targetKeys = Set<String>()
        for follow in follows {
            guard isValidFollowIdentifier(follow.id, maximumLength: 160),
                  isValidFollowIdentifier(follow.entityID),
                  follow.createdAt <= maximumCreatedAt,
                  follow.hasMatchingEntitySnapshot,
                  followIDs.insert(follow.id).inserted,
                  targetKeys.insert(
                    followTargetKey(type: follow.type, entityID: follow.entityID)
                  ).inserted else {
                throw SportsDataError.contractViolation(field: "follows")
            }
        }
        return follows.canonicalFollowOrder
    }

    private static func followTargetKey(
        type: FollowEntityType,
        entityID: String
    ) -> String {
        "\(type.rawValue):\(entityID)"
    }

    private static func followIdentityKey(accountID: String?) -> String {
        accountID.map { "account:\($0)" } ?? "guest"
    }

    private static func isValidFollowIdentifier(
        _ value: String,
        maximumLength: Int = 128
    ) -> Bool {
        let forbidden = CharacterSet(charactersIn: "/\\?#")
        return (1...maximumLength).contains(value.count)
            && value.rangeOfCharacter(from: forbidden) == nil
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}
