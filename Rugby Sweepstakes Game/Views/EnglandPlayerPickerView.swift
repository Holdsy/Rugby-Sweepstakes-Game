import SwiftUI

struct EnglandPlayerSummary: View {
    let player: EnglandSquadPlayer?
    let fallbackName: String
    var teamName: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            PlayerPortrait(name: fallbackName, remoteURL: player?.photoURL ?? PlayerPhotoCatalogue.url(named: fallbackName), teamName: teamName)
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(player?.name ?? (fallbackName.isEmpty ? "Choose player" : fallbackName))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                if let player {
                    HStack(spacing: 8) {
                        if let age = player.age {
                            Text("Age \(age)")
                        }
                        if let caps = player.caps { Text("\(caps) caps") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct TeamMemberProfileView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let member: TeamMember
    var imageSize: CGFloat = 40
    var namePrefix: String = ""

    private var squadPlayer: EnglandSquadPlayer? {
        viewModel.englandSquadPlayer(named: member.name)
    }

    var body: some View {
        HStack(spacing: 10) {
            PlayerPortrait(name: member.name, remoteURL: squadPlayer?.photoURL ?? PlayerPhotoCatalogue.url(named: member.name), teamName: viewModel.game.selectedTeamName)
            .frame(width: imageSize, height: imageSize)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(namePrefix + member.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if let position = member.position {
                        Text(position)
                    }
                    if let age = squadPlayer?.age {
                        Text("Age \(age)")
                    }
                    if let squadPlayer {
                        Text(squadPlayer.caps.map { "\($0) caps" } ?? "Uncapped")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct EnglandPlayerPickerView: View {
    let players: [EnglandSquadPlayer]
    let currentPlayer: EnglandSquadPlayer?
    let onSelect: (EnglandSquadPlayer?) -> Void
    var teamName: String? = "England"
    @State private var searchText = ""

    private var filteredPlayers: [EnglandSquadPlayer] {
        guard !searchText.isEmpty else {
            return players
        }
        return players.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if currentPlayer != nil {
                    Button(role: .destructive) {
                        onSelect(nil)
                    } label: {
                        Label("Clear Player", systemImage: "xmark.circle")
                    }
                }

                ForEach(filteredPlayers) { player in
                    Button {
                        onSelect(player)
                    } label: {
                        EnglandPlayerSummary(player: player, fallbackName: player.name, teamName: teamName)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search players")
            .navigationTitle("Choose \(teamName ?? "Squad") Player")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Shared framing and caching for squad, allocation and scoring portraits.
struct PlayerPortrait: View {
    let name: String
    let remoteURL: URL?
    var teamName: String? = nil
    @ObservedObject private var library = PlayerPhotoLibrary.shared
    @State private var downloadedImage: UIImage?
    @State private var loadedURL: URL?

    private var initials: String {
        name.split(whereSeparator: { $0.isWhitespace }).prefix(2)
            .compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Circle().fill(Color.secondary.opacity(0.08))
                if let asset = PlayerPhotoCatalogue.assetName(named: name) {
                    portrait(Image(asset), size: geometry.size)
                } else if loadedURL != nil, let downloadedImage {
                    portrait(Image(uiImage: downloadedImage), size: geometry.size)
                } else {
                    if initials.isEmpty {
                        Image(systemName: "person.fill")
                            .font(.system(size: geometry.size.width * 0.45))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text(initials)
                            .font(.system(size: geometry.size.width * 0.32, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .clipShape(Circle())
            .overlay { Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5) }
        }
        .accessibilityHidden(true)
        .task(id: "\(name)|\(teamName ?? "")|\(remoteURL?.absoluteString ?? "")|\(library.revision)") {
            downloadedImage = nil; loadedURL = nil
            guard PlayerPhotoCatalogue.assetName(named: name) == nil else { return }
            let preferred = library.officialPhoto(name: name, team: teamName) ?? remoteURL
            if let preferred, let image = await PlayerPortraitCache.image(at: preferred) {
                guard !Task.isCancelled else { return }
                downloadedImage = image; loadedURL = preferred
                return
            }
            guard !Task.isCancelled else { return }
            if let fallback = await library.sportsPhoto(name: name, team: teamName),
               let image = await PlayerPortraitCache.image(at: fallback), !Task.isCancelled {
                downloadedImage = image; loadedURL = fallback
            }
        }
    }

    private func portrait(_ image: Image, size: CGSize) -> some View {
        image.resizable().scaledToFit()
            .frame(width: size.width, height: size.height, alignment: .bottom)
    }
}

@MainActor
enum PlayerPortraitCache {
    private static let images = NSCache<NSURL, UIImage>()

    static func image(at url: URL) async -> UIImage? {
        if let cached = images.object(forKey: url as NSURL) { return cached }
        do {
            var request = URLRequest(url: url); request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  let image = UIImage(data: data) else { return nil }
            images.countLimit = 100
            images.totalCostLimit = 32 * 1024 * 1024
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count
            images.setObject(image, forKey: url as NSURL, cost: cost)
            return image
        } catch {
            return nil
        }
    }
}
