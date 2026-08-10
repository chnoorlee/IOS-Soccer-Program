import Foundation
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var authentication: AuthenticationManager
    @EnvironmentObject private var linkCoordinator: SportsHubLinkCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appModel.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: appModel.hasCompletedOnboarding
        )
        .task {
            async let subscriptionStartup: Void = appModel.subscriptionStore.start()
            await authentication.bootstrap()
            await appModel.prepareUITestHistoryIfRequested()
            await appModel.synchronizeFollows()
            await appModel.notificationSettings.refresh()
            await subscriptionStartup
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationStateDidChange)) { _ in
            Task {
                await appModel.synchronizeFollows()
                await appModel.notificationSettings.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await authentication.refreshSessionIfNeeded()
                await appModel.synchronizeFollows()
                await appModel.notificationSettings.refresh()
                await appModel.subscriptionStore.refreshEntitlementStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .apnsDeviceTokenDidRegister)) {
            notification in
            guard let token = notification.object as? Data else { return }
            Task {
                await appModel.notificationSettings.registerDeviceToken(
                    token,
                    locale: appModel.language.locale.identifier,
                    timeZone: TimeZone.current.identifier
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .apnsRegistrationDidFail)) { _ in
            appModel.notificationSettings.handleRegistrationFailure()
        }
        .onOpenURL { url in
            linkCoordinator.receive(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            linkCoordinator.receive(url)
        }
        .alert(
            "following.syncFailed",
            isPresented: Binding(
                get: { appModel.followError != nil },
                set: { isPresented in
                    if !isPresented { appModel.dismissFollowError() }
                }
            )
        ) {
            Button("action.dismiss", role: .cancel) {
                appModel.dismissFollowError()
            }
        } message: {
            Text("following.syncFailedBody")
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var linkCoordinator: SportsHubLinkCoordinator
    @State private var selection: AppTab = .home
    @State private var matchesPath: [SportsHubRoute] = []
    @State private var explorePath: [SportsHubRoute] = []

    var body: some View {
        TabView(selection: $selection) {
            tab(.home) {
                NavigationStack { HomeView() }
            }

            tab(.matches) {
                NavigationStack(path: $matchesPath) {
                    MatchesView()
                        .navigationDestination(for: SportsHubRoute.self) { route in
                            linkedDestination(route)
                        }
                }
            }

            tab(.explore) {
                NavigationStack(path: $explorePath) {
                    ExploreView()
                        .navigationDestination(for: SportsHubRoute.self) { route in
                            linkedDestination(route)
                        }
                }
            }

            tab(.following) {
                NavigationStack { FollowingView() }
            }

            tab(.profile) {
                NavigationStack { ProfileView() }
            }
        }
        .accessibilityIdentifier("main.tabView")
        .onAppear {
            routePendingLink()
        }
        .onChange(of: linkCoordinator.pendingRoute) { _, pendingRoute in
            guard pendingRoute != nil else { return }
            routePendingLink()
        }
        .alert(
            "link.unsupported.title",
            isPresented: Binding(
                get: { linkCoordinator.presentationError != nil },
                set: { isPresented in
                    if !isPresented { linkCoordinator.dismissPresentationError() }
                }
            )
        ) {
            Button("action.dismiss", role: .cancel) {
                linkCoordinator.dismissPresentationError()
            }
        } message: {
            Text("link.unsupported.body")
        }
    }

    @ViewBuilder
    private func tab<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .tabItem {
                Label(LocalizedStringKey(tab.titleKey), systemImage: tab.systemImage)
            }
            .tag(tab)
    }

    @ViewBuilder
    private func linkedDestination(_ route: SportsHubRoute) -> some View {
        switch route {
        case let .fixture(id):
            MatchCenterView(fixtureID: id)
        case let .article(id):
            ArticleDetailView(articleID: id)
        case let .video(id):
            VideoDetailView(videoID: id)
        case let .team(id):
            TeamDetailView(teamID: id)
        case let .player(id):
            PlayerDetailView(playerID: id)
        case let .competition(id):
            CompetitionLinkDestinationView(competitionID: id)
        }
    }

    private func routePendingLink() {
        guard let route = linkCoordinator.consumePendingRoute() else { return }
        selection = route.preferredTab
        switch route.preferredTab {
        case .matches:
            matchesPath = [route]
        case .explore:
            explorePath = [route]
        case .home, .following, .profile:
            break
        }
    }
}
