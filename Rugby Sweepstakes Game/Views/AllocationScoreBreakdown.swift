import SwiftUI

struct AllocationScoreBreakdown: View {
    let game: Game
    let bundleID: UUID
    @EnvironmentObject private var viewModel: GameViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Allocation total").foregroundStyle(.secondary)
                Spacer()
                Text("\(game.pointsForBundle(bundleID)) pts").fontWeight(.semibold).monospacedDigit()
            }.font(.caption)
            ForEach(game.allocationContributions(for: bundleID)) { contribution in
                HStack(spacing: 10) {
                    PlayerPortrait(name: contribution.member.name,
                        remoteURL: viewModel.englandSquadPlayer(named: contribution.member.name)?.photoURL ?? PlayerPhotoCatalogue.url(named: contribution.member.name),
                        teamName: game.selectedTeamName).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(contribution.member.name).font(.subheadline)
                        Text("\(contribution.isReplacement ? "Replacement" : "Starter") · \(contribution.isOnField ? "On field" : "Off field")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text("\(contribution.points) pts").font(.subheadline.monospacedDigit())
                }
            }
            if game.earlierAllocationPoints(for: bundleID) != 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Earlier combined points")
                        Spacer()
                        Text("\(game.earlierAllocationPoints(for: bundleID)) pts").monospacedDigit()
                    }
                    Text("Recorded before individual scoring history was available.")
                }.font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
    }
}
