import SwiftUI

struct PhotoSourcesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = PlayerPhotoLibrary.shared
    @State private var showAdd = false
    @State private var team = ""
    @State private var url = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Save squad pages to supply player names and photos. Match the team name to your fixture, then open its page to load or refresh the catalogue.")
                    Text("These are squad catalogues, not confirmed matchday lineups. Choose the correct 23 on the team review screen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Photo pages") {
                    ForEach(library.sources) { source in
                        NavigationLink {
                            PhotoSourceDetail(id: source.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.team).font(.headline)
                                Text(source.url.host ?? source.url.absoluteString).font(.caption).foregroundStyle(.secondary)
                                Text(source.updatedAt == nil ? "Not loaded" : "\(source.players.count) players saved")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { library.sources[$0].id }
                        for id in ids { library.remove(id: id) }
                    }
                    Button { showAdd = true } label: { Label("Add Photo Page", systemImage: "plus") }
                }
                Section("Automatic fallback") {
                    Text("If no saved portrait is available, the app checks TheSportsDB for an exact rugby player name and matching club or nationality. Cutouts are preferred; missing or ambiguous matches keep initials.")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("TheSportsDB", destination: URL(string: "https://www.thesportsdb.com")!)
                }
            }
            .navigationTitle("Photo Pages & Squads").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showAdd) {
                NavigationStack {
                    Form {
                        TextField("Team name, e.g. Ireland", text: $team)
                        TextField("HTTPS squad-page link", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Text("Use an official squad page with names beside player photos. Website layouts vary; unsupported pages leave your saved photos unchanged.")
                            .font(.caption).foregroundStyle(.secondary)
                        if let error { Text(error).foregroundStyle(.orange) }
                    }
                    .navigationTitle("Add Photo Page").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showAdd = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save Page") {
                                do { try library.add(team: team, urlString: url); team = ""; url = ""; error = nil; showAdd = false }
                                catch { self.error = error.localizedDescription }
                            }.disabled(team.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.isEmpty)
                        }
                    }
                }
            }
        }
    }
}

private struct PhotoSourceDetail: View {
    let id: UUID
    @ObservedObject private var library = PlayerPhotoLibrary.shared
    @State private var loading = false
    @State private var error: String?
    @State private var search = ""
    private var source: PhotoSquadSource? { library.sources.first { $0.id == id } }
    var body: some View {
        List {
            if let source {
                Section {
                    Link("Open Original Squad Page", destination: source.url)
                    Button(loading ? "Loading Squad…" : "Refresh Squad & Photos") { Task { await refresh() } }.disabled(loading)
                    if let updatedAt = source.updatedAt { Text("Updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                    if let error { Text(error).foregroundStyle(.orange) }
                    if loading { ProgressView() }
                }
                Section("\(source.players.count) saved players") {
                    ForEach(source.players.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { player in
                        HStack(spacing: 12) {
                            PlayerPortrait(name: player.name, remoteURL: player.photoURL, teamName: source.team).frame(width: 52, height: 52)
                            Text(player.name)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Find player")
        .navigationTitle(source?.team ?? "Squad Photos").navigationBarTitleDisplayMode(.inline)
        .task { if source?.updatedAt == nil { await refresh() } }
    }
    private func refresh() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        do { try await library.refresh(id: id) }
        catch { self.error = error.localizedDescription }
    }
}
