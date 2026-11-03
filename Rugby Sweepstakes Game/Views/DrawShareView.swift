import SwiftUI
import UIKit

/// A complete allocation poster, rendered after photos load so exported images match the preview.
struct DrawShareView: View {
    let game: Game
    let englandSquad: [EnglandSquadPlayer]
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [UUID: UIImage] = [:]
    @State private var image: UIImage?
    @State private var preparing = true
    @State private var loaded = 0
    @State private var error: String?
    @State private var shareImage = false
    @State private var shareText = false

    private var members: [TeamMember] { DrawSharePoster.members(in: game) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if preparing {
                        ProgressView("Preparing player photos · \(loaded) of \(members.count)")
                            .padding()
                    }
                    if let error { Text(error).foregroundStyle(.orange).padding(.horizontal) }
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Draw image for \(game.displayTitle), including all participant allocations")
                            .padding(.horizontal)
                    }
                    if !preparing {
                        Text("\(photos.count) of \(members.count) player photos available. Initials are used for missing photos.")
                            .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                        Text("Share Image opens the iPhone share sheet. Choose WhatsApp or another app to send it.")
                            .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                    }
                }.padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Share Your Draw").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button { shareImage = true } label: {
                        Label("Share Image", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large).disabled(preparing || image == nil)
                    Button("Share as Text") { shareText = true }
                }.padding().background(.regularMaterial)
            }
            .task { await prepare() }
            .sheet(isPresented: $shareImage) { if let image { ShareSheet(activityItems: [image]) } }
            .sheet(isPresented: $shareText) { ShareSheet(activityItems: [DrawSharePoster.text(for: game)]) }
        }
    }
    @MainActor private func prepare() async {
        guard game.isDrawComplete else { preparing = false; error = "Run the draw before sharing allocations."; return }
        render()
        await withTaskGroup(of: (UUID, UIImage?).self) { group in
            for member in members {
                group.addTask { @MainActor in (member.id, await loadPhoto(member)) }
            }
            for await (id, photo) in group {
                guard !Task.isCancelled else { group.cancelAll(); return }
                if let photo { photos[id] = photo }
                loaded += 1
            }
        }
        guard !Task.isCancelled else { return }
        render(); preparing = false
    }
    @MainActor private func loadPhoto(_ member: TeamMember) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        if let asset = PlayerPhotoCatalogue.assetName(named: member.name), let local = UIImage(named: asset) { return local }
        let library = PlayerPhotoLibrary.shared
        let england = game.selectedTeamName?.caseInsensitiveCompare("England") == .orderedSame
        let known = england ? EnglandPlayerNameMatcher.index(named: member.name, in: englandSquad.map(\.name)).flatMap { englandSquad[$0].photoURL } : nil
        let preferred = library.officialPhoto(name: member.name, team: game.selectedTeamName) ?? known ?? PlayerPhotoCatalogue.url(named: member.name)
        if let preferred, let photo = await PlayerPortraitCache.image(at: preferred) { return photo }
        guard !Task.isCancelled else { return nil }
        if let url = await library.sportsPhoto(name: member.name, team: game.selectedTeamName) { return await PlayerPortraitCache.image(at: url) }
        return nil
    }
    @MainActor private func render() {
        let renderer = ImageRenderer(content: DrawSharePoster(game: game, photos: photos).environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)
        renderer.scale = 1
        image = renderer.uiImage
        if image == nil { error = "The draw image could not be created. You can still share the allocations as text." }
    }
}

struct DrawSharePoster: View {
    let game: Game
    let photos: [UUID: UIImage]
    private let ink = Color(red: 0.06, green: 0.15, blue: 0.22)
    private var participants: [SweepstakePlayer] { game.sweepstakePlayers }
    static func members(in game: Game) -> [TeamMember] {
        let assigned = Set(game.sweepstakePlayers.flatMap(\.assignedTeamMemberIds))
        let substitutes = Set(game.teamMembers.filter { assigned.contains($0.id) }.compactMap(\.linkedSubstituteId))
        return game.teamMembers.filter { assigned.contains($0.id) || substitutes.contains($0.id) }
    }
    static func text(for game: Game) -> String {
        var lines = ["RUCK OF THE DRAW · YOUR DRAW", game.displayTitle]
        if let team = game.selectedTeamName { lines.append("Following \(team)") }
        for participant in game.sweepstakePlayers {
            lines.append("\n\(participant.name)")
            for id in participant.assignedTeamMemberIds {
                guard let index = game.teamMembers.firstIndex(where: { $0.id == id }) else { continue }
                let member = game.teamMembers[index]
                lines.append("  #\(index + 1) \(member.name)")
                if let replacement = game.teamMembers.first(where: { $0.id == member.linkedSubstituteId }) { lines.append("    Replacement: \(replacement.name)") }
            }
        }
        lines.append("\nYour starters and their replacements score for you.")
        return lines.joined(separator: "\n")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 14) {
                Image(systemName: "sportscourt.fill").font(.system(size: 28))
                Text("RUCK OF THE DRAW").font(.system(size: 23, weight: .bold, design: .rounded)).tracking(3)
                Spacer()
                Text("YOUR DRAW").font(.system(size: 19, weight: .bold)).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.white.opacity(0.15), in: Capsule())
            }.foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 12) {
                Text(game.displayTitle).font(.system(size: 48, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(game.selectedTeamName.map { "Following \($0) · " } ?? "")\(participants.count) participants · \(participants.reduce(0) { $0 + $1.assignedTeamMemberIds.count }) players allocated")
                    .font(.system(size: 23, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            }.foregroundStyle(.white)
            Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 20) {
                ForEach(Array(stride(from: 0, to: participants.count, by: 2)), id: \.self) { index in
                    GridRow(alignment: .top) {
                        participantCard(participants[index])
                        if index + 1 < participants.count { participantCard(participants[index + 1]) }
                        else { Color.clear.frame(width: 488, height: 1) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Your starters and their replacements score for you.").font(.system(size: 23, weight: .semibold))
                Text("Keep this draw handy for match day.").font(.system(size: 20)).foregroundStyle(.white.opacity(0.7))
            }.foregroundStyle(.white).padding(.top, 2)
        }
        .padding(42).frame(width: 1080, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.04, green: 0.24, blue: 0.25), Color(red: 0.04, green: 0.11, blue: 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
    private func participantCard(_ participant: SweepstakePlayer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 4).fill(participant.color.color).frame(width: 8, height: 32)
                Text(participant.name).font(.system(size: 29, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(ink.opacity(0.1)).frame(height: 1)
            ForEach(participant.assignedTeamMemberIds, id: \.self) { id in
                if let index = game.teamMembers.firstIndex(where: { $0.id == id }) {
                    let member = game.teamMembers[index]
                    playerRow(member, shirt: index + 1, replacement: false)
                    if let subIndex = game.teamMembers.firstIndex(where: { $0.id == member.linkedSubstituteId }) {
                        playerRow(game.teamMembers[subIndex], shirt: subIndex + 1, replacement: true)
                    }
                }
            }
            if participant.assignedTeamMemberIds.isEmpty { Text("No players allocated").font(.system(size: 22)).foregroundStyle(ink.opacity(0.6)) }
        }
        .padding(22).frame(width: 488, alignment: .leading)
        .foregroundStyle(ink).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
    private func playerRow(_ member: TeamMember, shirt: Int, replacement: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(ink.opacity(0.06))
                if let photo = photos[member.id] {
                    Image(uiImage: photo).resizable().scaledToFit()
                } else {
                    Text(member.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased())
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(ink.opacity(0.45))
                }
            }.frame(width: 64, height: 64).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name).font(.system(size: 23, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(replacement ? "#\(shirt) · Replacement on" : "#\(shirt) · Starter")
                    .font(.system(size: 18)).foregroundStyle(ink.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
    }
}
