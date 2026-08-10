import SwiftUI

struct MatchesFollowReasonLabel: View {
    let reason: FixtureFollowReason
    let identifier: String

    var body: some View {
        Label(
            LocalizedStringKey(reason.matchesLocalizationKey),
            systemImage: "star.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.primary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(identifier)
    }
}
