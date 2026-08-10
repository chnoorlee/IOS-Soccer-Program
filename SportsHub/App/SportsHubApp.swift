import SwiftUI

@main
struct SportsHubApp: App {
    @UIApplicationDelegateAdaptor(SportsHubAppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()
    @StateObject private var linkCoordinator = SportsHubLinkCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .environmentObject(appModel.authentication)
                .environmentObject(appModel.subscriptionStore)
                .environmentObject(appModel.notificationSettings)
                .environmentObject(linkCoordinator)
                .environment(\.locale, appModel.language.locale)
                .environment(\.layoutDirection, appModel.language.layoutDirection)
                .tint(AppTheme.accent)
        }
    }
}
