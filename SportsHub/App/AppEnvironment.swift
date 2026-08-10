import Foundation

enum SportsDataMode: String, Sendable {
    case mock
    case remote
    case remoteWithMockFallback
}

struct AppServices {
    let dataProvider: any SportsDataProviding
    let authentication: AuthenticationManager
    let subscriptionStore: PremiumSubscriptionModel
    let notificationPermissions: any NotificationPermissionCoordinating
    let publicCache: any SportsDataCacheManaging
    let publicContentFreshness: any PublicContentFreshnessReading
    let usesDemoPublicData: Bool
    let communityConfiguration: CommunityConfiguration

    @MainActor
    init(
        dataProvider: any SportsDataProviding,
        authentication: AuthenticationManager,
        subscriptionStore: PremiumSubscriptionModel? = nil,
        notificationPermissions: any NotificationPermissionCoordinating = SystemNotificationPermissionCoordinator(),
        publicCache: any SportsDataCacheManaging = MemorySportsDataCache(),
        publicContentFreshness: any PublicContentFreshnessReading = PublicContentFreshnessStore(),
        usesDemoPublicData: Bool = true,
        communityConfiguration: CommunityConfiguration = .developmentDisabled
    ) {
        self.dataProvider = dataProvider
        self.authentication = authentication
        self.subscriptionStore = subscriptionStore ?? .unavailable()
        self.notificationPermissions = notificationPermissions
        self.publicCache = publicCache
        self.publicContentFreshness = publicContentFreshness
        self.usesDemoPublicData = usesDemoPublicData
        self.communityConfiguration = communityConfiguration
    }
}

enum AppEnvironment {
    private struct PublicCacheServices {
        let dataCache: any SportsDataCaching
        let manager: any SportsDataCacheManaging
    }

    @MainActor
    static func makeServices(bundle: Bundle = .main) -> AppServices {
        let guestStore = FilePersonalVideoStateStore()
        let sessionStore = KeychainAuthSessionStore()
        let publicCache = makePublicCacheServices()
        let freshnessStore = makePublicContentFreshnessStore()
        let communityConfiguration = CommunityConfiguration.from(bundle: bundle)
        let subscriptionStore = makePremiumSubscriptionStore(bundle: bundle)
        let simulatesOfflineFreshness = simulatesOfflineFreshnessForUITest
        let rawMode = bundle.object(forInfoDictionaryKey: "SportsDataMode") as? String
        let mode = SportsDataMode(rawValue: rawMode ?? "mock")

        guard let mode else {
            return unavailableServices(
                base: FailingSportsDataProvider(error: .invalidConfiguration),
                guestStore: guestStore,
                sessionStore: sessionStore,
                publicCache: publicCache.manager,
                publicContentFreshness: freshnessStore,
                usesDemoPublicData: false,
                subscriptionStore: subscriptionStore
            )
        }
        guard mode != .mock else {
            return unavailableServices(
                base: MockSportsDataProvider(),
                guestStore: guestStore,
                sessionStore: sessionStore,
                publicCache: publicCache.manager,
                publicContentFreshness: freshnessStore,
                usesDemoPublicData: !simulatesOfflineFreshness,
                subscriptionStore: subscriptionStore
            )
        }

        guard let rawURL = bundle.object(forInfoDictionaryKey: "SportsAPIBaseURL") as? String,
              let baseURL = URL(string: rawURL) else {
            return unavailableServices(
                base: FailingSportsDataProvider(error: .invalidConfiguration),
                guestStore: guestStore,
                sessionStore: sessionStore,
                publicCache: publicCache.manager,
                publicContentFreshness: freshnessStore,
                usesDemoPublicData: false,
                subscriptionStore: subscriptionStore
            )
        }

        let authClient: (any AuthenticationClient)?
        let sessionCoordinator: (any AuthSessionCoordinating)?
        let tokenProvider: any AccessTokenProviding
        if authenticationEnabled(in: bundle),
           let remoteAuthClient = try? RemoteAuthenticationClient(baseURL: baseURL) {
            let coordinator = AuthSessionCoordinator(
                store: sessionStore,
                client: remoteAuthClient
            )
            authClient = remoteAuthClient
            sessionCoordinator = coordinator
            tokenProvider = CoordinatedSessionAccessTokenProvider(coordinator: coordinator)
        } else {
            authClient = nil
            sessionCoordinator = nil
            tokenProvider = NoAccessTokenProvider()
        }

        guard let remote = try? RemoteSportsDataProvider(
            baseURL: baseURL,
            cache: publicCache.dataCache,
            accessTokenProvider: tokenProvider,
            freshnessReporter: freshnessStore
        ) else {
            return unavailableServices(
                base: FailingSportsDataProvider(error: .invalidConfiguration),
                guestStore: guestStore,
                sessionStore: sessionStore,
                publicCache: publicCache.manager,
                publicContentFreshness: freshnessStore,
                usesDemoPublicData: false,
                subscriptionStore: subscriptionStore
            )
        }

        let publicBase: any SportsDataProviding
        switch mode {
        case .mock:
            publicBase = MockSportsDataProvider()
        case .remote:
            publicBase = remote
        case .remoteWithMockFallback:
            publicBase = FallbackSportsDataProvider(
                primary: remote,
                fallback: MockSportsDataProvider(),
                freshnessReporter: freshnessStore
            )
        }

        guard let authClient, let sessionCoordinator else {
            return unavailableServices(
                base: publicBase,
                guestStore: guestStore,
                sessionStore: sessionStore,
                publicCache: publicCache.manager,
                publicContentFreshness: freshnessStore,
                usesDemoPublicData: false,
                subscriptionStore: subscriptionStore
            )
        }

        let guestProvider = LocalPersonalizationSportsDataProvider(
            base: publicBase,
            store: guestStore
        )
        let provider = SessionPersonalizationSportsDataProvider(
            base: publicBase,
            authenticated: remote,
            guest: guestProvider,
            sessionStore: sessionCoordinator,
            communityMutationsEnabled: communityConfiguration.isReleaseGateSatisfied
        )
        let authentication = AuthenticationManager(
            isAvailable: true,
            client: authClient,
            sessionCoordinator: sessionCoordinator,
            guestStore: guestStore
        )
        return AppServices(
            dataProvider: provider,
            authentication: authentication,
            subscriptionStore: subscriptionStore,
            publicCache: publicCache.manager,
            publicContentFreshness: freshnessStore,
            usesDemoPublicData: false,
            communityConfiguration: communityConfiguration
        )
    }

    @MainActor
    static func makeSportsDataProvider(bundle: Bundle = .main) -> any SportsDataProviding {
        makeServices(bundle: bundle).dataProvider
    }

    @MainActor
    static func makeUnavailableAuthenticationManager(
        guestStore: any PersonalVideoStateStoring = FilePersonalVideoStateStore()
    ) -> AuthenticationManager {
        let client = UnavailableAuthenticationClient()
        let coordinator = AuthSessionCoordinator(
            store: KeychainAuthSessionStore(),
            client: client
        )
        return AuthenticationManager(
            isAvailable: false,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore
        )
    }

    @MainActor
    private static func unavailableServices(
        base: any SportsDataProviding,
        guestStore: any PersonalVideoStateStoring,
        sessionStore: any AuthSessionStoring,
        publicCache: any SportsDataCacheManaging,
        publicContentFreshness: any PublicContentFreshnessReading,
        usesDemoPublicData: Bool,
        subscriptionStore: PremiumSubscriptionModel
    ) -> AppServices {
        let client = UnavailableAuthenticationClient()
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client
        )
        let guestProvider = LocalPersonalizationSportsDataProvider(
            base: base,
            store: guestStore
        )
        return AppServices(
            dataProvider: guestProvider,
            authentication: AuthenticationManager(
                isAvailable: false,
                client: client,
                sessionCoordinator: coordinator,
                guestStore: guestStore
            ),
            subscriptionStore: subscriptionStore,
            publicCache: publicCache,
            publicContentFreshness: publicContentFreshness,
            usesDemoPublicData: usesDemoPublicData
        )
    }

    private static func makePublicCacheServices() -> PublicCacheServices {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-test-seed-public-cache") {
            let cache = MemorySportsDataCache(initialPayloads: [
                "ui-test-public-cache": CachedPayload(
                    data: Data("ui-test-public-cache".utf8),
                    storedAt: Date(timeIntervalSince1970: 1_788_000_000),
                    etag: "ui-test-v1"
                )
            ])
            return PublicCacheServices(dataCache: cache, manager: cache)
        }
        #endif
        let cache = FileSportsDataCache()
        return PublicCacheServices(dataCache: cache, manager: cache)
    }

    @MainActor
    private static func makePremiumSubscriptionStore(
        bundle: Bundle
    ) -> PremiumSubscriptionModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-test-premium-preview") {
            return PremiumSubscriptionModel(
                configuration: .preview,
                client: PreviewSubscriptionStoreClient()
            )
        }
        #endif
        return PremiumSubscriptionModel(
            configuration: PremiumSubscriptionConfiguration.from(bundle: bundle),
            client: StoreKitSubscriptionStoreClient()
        )
    }

    private static func makePublicContentFreshnessStore() -> PublicContentFreshnessStore {
        #if DEBUG
        if simulatesOfflineFreshnessForUITest {
            return PublicContentFreshnessStore(initialStatuses: [
                .home: .offlineSnapshot(
                    storedAt: Date(timeIntervalSince1970: 1_787_999_400),
                    checkedAt: Date(timeIntervalSince1970: 1_788_000_000)
                )
            ])
        }
        #endif
        return PublicContentFreshnessStore()
    }

    private static var simulatesOfflineFreshnessForUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ui-test-seed-offline-freshness")
        #else
        false
        #endif
    }

    private static func authenticationEnabled(in bundle: Bundle) -> Bool {
        if let value = bundle.object(forInfoDictionaryKey: "SportsAuthEnabled") as? Bool {
            return value
        }
        if let value = bundle.object(forInfoDictionaryKey: "SportsAuthEnabled") as? String {
            return ["1", "true", "yes"].contains(value.lowercased())
        }
        return false
    }
}
