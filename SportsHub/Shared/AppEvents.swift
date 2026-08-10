import Foundation

extension Notification.Name {
    static let watchProgressDidChange = Notification.Name("SportsHub.watchProgressDidChange")
    static let videoFavoritesDidChange = Notification.Name("SportsHub.videoFavoritesDidChange")
    static let articleFavoritesDidChange = Notification.Name("SportsHub.articleFavoritesDidChange")
    static let followsDidChange = Notification.Name("SportsHub.followsDidChange")
    static let authenticationStateDidChange = Notification.Name(
        "SportsHub.authenticationStateDidChange"
    )
    static let apnsDeviceTokenDidRegister = Notification.Name(
        "SportsHub.apnsDeviceTokenDidRegister"
    )
    static let apnsRegistrationDidFail = Notification.Name(
        "SportsHub.apnsRegistrationDidFail"
    )
}
