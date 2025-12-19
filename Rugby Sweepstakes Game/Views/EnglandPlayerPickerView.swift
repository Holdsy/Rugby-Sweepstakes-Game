import SwiftUI

struct EnglandPlayerSummary: View {
    let player: EnglandSquadPlayer?
    let fallbackName: String

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: player?.photoURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
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
                        Text(player.caps.map { "\($0) caps" } ?? "Uncapped")
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

struct EnglandPlayerPickerView: View {
    let players: [EnglandSquadPlayer]
    let currentPlayer: EnglandSquadPlayer?
    let onSelect: (EnglandSquadPlayer?) -> Void

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

                ForEach(players) { player in
                    Button {
                        onSelect(player)
                    } label: {
                        EnglandPlayerSummary(player: player, fallbackName: player.name)
                    }
                }
            }
            .navigationTitle("Choose England Player")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
