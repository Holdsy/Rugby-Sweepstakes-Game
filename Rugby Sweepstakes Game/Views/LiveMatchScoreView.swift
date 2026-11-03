import SwiftUI

struct LiveMatchScoreView: View {
    let matchID: Int?
    let providerName: String?
    @StateObject private var model = LiveMatchScoreModel()
    @State private var showConnection = false
    @State private var connected = HighlightlyCredentials.load() != nil
    private var isSample: Bool { providerName?.localizedCaseInsensitiveContains("sample") == true }
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Match Score", systemImage: "sportscourt").font(.headline)
                    Spacer()
                    if matchID != nil {
                        if model.loading { ProgressView().accessibilityLabel("Refreshing match score") }
                        Button {
                            if connected { Task { await refresh() } }
                            else { showConnection = true }
                        } label: { Label(connected ? "Refresh" : "Connect", systemImage: connected ? "arrow.clockwise" : "key") }
                        .buttonStyle(.borderless).disabled(model.loading)
                        .accessibilityLabel(connected ? "Refresh match score" : "Connect Highlightly for match scores")
                    }
                }
                if matchID == nil {
                    Text("No live fixture is linked to this game. Choose a Highlightly fixture when setting up your next game to see its match score here.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    if isSample { Text("Historical sample · scores refer to the original match.").font(.caption).foregroundStyle(.secondary) }
                    if let snapshot = model.snapshot {
                        HStack(alignment: .top, spacing: 12) {
                            team(snapshot.home, score: snapshot.scorePair?.first ?? "—")
                            Text("–").font(.title2).foregroundStyle(.secondary).padding(.top, 24)
                            team(snapshot.away, score: snapshot.scorePair?.last ?? "—")
                        }
                        Text(snapshot.statusText).font(.subheadline.weight(.semibold))
                        if snapshot.scorePair == nil {
                            if let raw = snapshot.score, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Provider score: \(raw)").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("The provider has not supplied a score yet.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last fetched \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                                if snapshot.isStale(at: context.date) { Text("Not refreshed recently · tap Refresh for the latest available score.").foregroundStyle(.orange) }
                            }.font(.caption).foregroundStyle(.secondary)
                        }
                    } else if !model.loading {
                        Text(connected ? "No match score has been loaded yet." : "Connect Highlightly to load this fixture’s score and match status.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else { Text("Loading match score…").font(.subheadline).foregroundStyle(.secondary) }
                    if let error = model.error {
                        Text(error).font(.caption).foregroundStyle(.orange)
                        if model.snapshot != nil { Text("Showing the last successfully retrieved score.").font(.caption).foregroundStyle(.secondary) }
                    }
                    Text("Scores may be delayed. Refresh to update; your sweepstake points are recorded manually.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 4)
        }
        .task(id: matchID) {
            model.configure(matchID: matchID)
            connected = HighlightlyCredentials.load() != nil
            if matchID != nil, connected { await refresh(force: false) }
        }
        .sheet(isPresented: $showConnection, onDismiss: {
            connected = HighlightlyCredentials.load() != nil
            if connected { Task { await refresh() } }
        }) { HighlightlyConnectionView() }
    }
    private func team(_ name: String, score: String) -> some View {
        VStack(spacing: 5) {
            Text(name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
            Text(score).font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit()
        }.frame(maxWidth: .infinity)
    }
    private func refresh(force: Bool = true) async {
        await model.refresh(key: HighlightlyCredentials.load() ?? "", force: force)
    }
}
