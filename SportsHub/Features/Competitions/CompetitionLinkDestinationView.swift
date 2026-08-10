import SwiftUI

struct CompetitionLinkDestinationView: View {
    @EnvironmentObject private var appModel: AppModel
    let competitionID: String

    @State private var competition: Competition?
    @State private var failed = false
    @State private var requestID: UUID?

    var body: some View {
        Group {
            if let competition {
                CompetitionDetailView(competition: competition)
            } else if failed {
                LoadStateView(state: .error) {
                    Task { await load() }
                }
            } else {
                LoadStateView(state: .loading)
            }
        }
        .background(AppTheme.background)
        .accessibilityIdentifier("competition.linkDestination")
        .task(id: competitionID) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        let currentRequestID = UUID()
        requestID = currentRequestID
        competition = nil
        failed = false

        do {
            let competitions = try await appModel.dataProvider.competitions()
            guard requestID == currentRequestID,
                  !Task.isCancelled else {
                return
            }
            competition = competitions.first { $0.id == competitionID }
            failed = competition == nil
        } catch is CancellationError {
            return
        } catch {
            guard requestID == currentRequestID,
                  !Task.isCancelled else {
                return
            }
            failed = true
        }
    }
}
