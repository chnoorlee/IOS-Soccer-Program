import SwiftUI

struct SportsFollowButton: View {
    @EnvironmentObject private var appModel: AppModel

    let type: FollowEntityType
    let entityID: String
    let entity: FollowEntitySnapshot
    let accessibilityIdentifier: String

    private var isFollowing: Bool {
        appModel.isFollowing(type: type, entityID: entityID)
    }

    private var isBusy: Bool {
        appModel.isFollowMutationInProgress(type: type, entityID: entityID)
    }

    var body: some View {
        Button {
            appModel.toggleFollow(type: type, entityID: entityID, entity: entity)
        } label: {
            if isBusy {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Label {
                    Text(LocalizedStringKey(isFollowing ? "action.following" : "action.follow"))
                } icon: {
                    Image(systemName: isFollowing ? "star.fill" : "star")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy)
        .accessibilityLabel(accessibilityActionLabel)
        .accessibilityValue(isBusy ? Text("accessibility.updating") : Text(""))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accessibilityActionLabel: Text {
        Text(LocalizedStringKey(
            isFollowing ? "accessibility.unfollowEntity" : "accessibility.followEntity"
        ))
        + Text(" ")
        + Text(LocalizedStringKey(type.localizationKey))
    }
}
