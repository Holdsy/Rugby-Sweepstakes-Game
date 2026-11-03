import SwiftUI
import UIKit

struct ResultsShareView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var error: String?
    @State private var shareImage = false
    @State private var shareText = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Final results image for \(game.displayTitle), including the winners and all final standings")
                    }
                    if let error { Text(error).foregroundStyle(.orange) }
                    Text("Share Image opens the iPhone share sheet. Choose WhatsApp or another app to send your final results.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Share Final Results").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button { shareImage = true } label: {
                        Label("Share Image", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large).disabled(image == nil)
                    Button("Share as Text") { shareText = true }.disabled(!game.isCompleted)
                }.padding().background(.regularMaterial)
            }
            .task { render() }
            .sheet(isPresented: $shareImage) { if let image { ShareSheet(activityItems: [image]) } }
            .sheet(isPresented: $shareText) { ShareSheet(activityItems: [game.resultsShareText]) }
        }
    }
    @MainActor private func render() {
        guard game.isCompleted else { error = "Finish and save this game before sharing final results."; return }
        let renderer = ImageRenderer(content: ResultsSharePoster(game: game).environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)
        renderer.scale = 1
        image = renderer.uiImage
        if image == nil { error = "The results image could not be created. You can still share the results as text." }
    }
}

/// Uses the saved game's calculations so sharing cannot change ranks, ties or historical results.
struct ResultsSharePoster: View {
    let game: Game
    private let ink = Color(red: 0.06, green: 0.15, blue: 0.22)
    private let gold = Color(red: 1, green: 0.79, blue: 0.32)
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 14) {
                Image(systemName: "sportscourt.fill").font(.system(size: 28))
                Text("RUCK OF THE DRAW").font(.system(size: 23, weight: .bold, design: .rounded)).tracking(3)
                Spacer()
                Text("FINAL RESULTS").font(.system(size: 19, weight: .bold))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.white.opacity(0.15), in: Capsule())
            }.foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 12) {
                Text(game.displayTitle).font(.system(size: 48, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                if let team = game.selectedTeamName {
                    Text("Following \(team)").font(.system(size: 23, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                }
            }.foregroundStyle(.white)
            if let winner = game.winningParticipants.first {
                VStack(alignment: .leading, spacing: 16) {
                    Label(game.winningParticipants.count == 1 ? "WINNER" : "JOINT WINNERS", systemImage: "trophy.fill")
                        .font(.system(size: 24, weight: .bold)).tracking(2).foregroundStyle(gold)
                    Text(game.winningParticipants.map(\.name).joined(separator: " · "))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true).foregroundStyle(.white)
                    Text("\(game.pointsForParticipant(winner.id)) points\(game.winningParticipants.count > 1 ? " each" : "")")
                        .font(.system(size: 31, weight: .semibold)).foregroundStyle(gold)
                }
                .padding(30).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(gold.opacity(0.5), lineWidth: 2) }
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("FINAL STANDINGS").tracking(2)
                    Spacer()
                    Text("\(game.sweepstakePlayers.count) participants")
                }.font(.system(size: 21, weight: .bold)).foregroundStyle(ink.opacity(0.65)).padding(.bottom, 20)
                ForEach(Array(game.rankedParticipants.enumerated()), id: \.element.id) { index, participant in
                    if index > 0 { Rectangle().fill(ink.opacity(0.1)).frame(height: 1).padding(.vertical, 18) }
                    HStack(alignment: .center, spacing: 18) {
                        Text("\(game.participantRank(participant.id))")
                            .font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit().frame(width: 48)
                            .foregroundStyle(game.participantRank(participant.id) == 1 ? Color(red: 0.65, green: 0.4, blue: 0.06) : ink.opacity(0.6))
                        RoundedRectangle(cornerRadius: 4).fill(participant.color.color).frame(width: 8, height: 30)
                        Text(participant.name).font(.system(size: 29, weight: .semibold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 16)
                        Text("\(game.pointsForParticipant(participant.id)) pts")
                            .font(.system(size: 29, weight: .bold)).monospacedDigit().fixedSize()
                    }.foregroundStyle(ink)
                }
                if game.sweepstakePlayers.isEmpty { Text("No participants recorded.").font(.system(size: 26)).foregroundStyle(ink) }
            }
            .padding(30).background(.white, in: RoundedRectangle(cornerRadius: 24))
            Text("Final sweepstake standings · Equal scores share a rank")
                .font(.system(size: 21)).foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(42).frame(width: 1080, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.04, green: 0.24, blue: 0.25), Color(red: 0.04, green: 0.11, blue: 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
