import SwiftUI

struct SportsShareButton: View {
    @EnvironmentObject private var linkCoordinator: SportsHubLinkCoordinator

    let route: SportsHubRoute
    let fallbackText: String
    let accessibilityHint: LocalizedStringKey

    var body: some View {
        Group {
            if let publicURL = linkCoordinator.publicURL(for: route) {
                ShareLink(item: publicURL) {
                    shareLabel
                }
            } else {
                ShareLink(item: fallbackText) {
                    shareLabel
                }
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("action.share"))
        .accessibilityHint(Text(accessibilityHint))
        .accessibilityIdentifier("share.\(route.collection).\(route.entityID)")
    }

    private var shareLabel: some View {
        Label("action.share", systemImage: "square.and.arrow.up")
    }
}
