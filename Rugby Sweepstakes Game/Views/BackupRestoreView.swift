import SwiftUI
import UniformTypeIdentifiers

struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw AppBackupService.BackupError.invalid }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupRestoreView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var exportDocument: BackupFileDocument?
    @State private var exportName = "Rugby Sweepstakes Backup"
    @State private var exportType = UTType.json
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var preview: RugbyAppBackup?
    @State private var confirmRestore = false
    @State private var error: String?
    @State private var status: String?
    @State private var recoveryFiles: [URL] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Back up your app") {
                    Text("Save a backup to Files or iCloud Drive, then use it to recover your app or move to another device.")
                    Button { exportCurrent() } label: { Label("Export Backup", systemImage: "square.and.arrow.up") }
                        .disabled(viewModel.storageWritesBlocked)
                    Text("Includes the current game, saved games, participants, unfinished team drafts and photo-page catalogues. Private API keys stay in the device Keychain. Portrait images are downloaded again when needed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Restore from a file") {
                    Button { error = nil; status = nil; showImporter = true } label: {
                        Label("Choose Backup File", systemImage: "square.and.arrow.down")
                    }
                    Text("You can inspect a backup before restoring it. Restore replaces this app’s saved games and settings; it does not merge them. Your existing API key stays unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let preview {
                    Section("Backup preview") {
                        LabeledContent("Created", value: preview.createdAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Current game", value: preview.state.game.displayTitle)
                        LabeledContent("Saved games", value: "\(preview.state.savedGames.count)")
                        LabeledContent("Saved participants", value: "\(preview.participants.count)")
                        LabeledContent("Team drafts", value: "\(preview.drafts.count)")
                        LabeledContent("Photo pages", value: "\(preview.photoSources.count)")
                        Button("Restore This Backup", role: .destructive) { confirmRestore = true }
                        Button("Cancel Preview") { self.preview = nil }
                    }
                }
                if let status { Section { Label(status, systemImage: "checkmark.circle.fill").foregroundStyle(.green) } }
                if let error { Section { Text(error).foregroundStyle(.orange) } }
                if !recoveryFiles.isEmpty {
                    Section("Before-restore recovery copies") {
                        Text("A local copy is kept before each restore. Export one here to keep it outside the app. JSON copies can be restored using Choose Backup File; PLIST copies preserve unreadable original data for recovery.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(recoveryFiles, id: \.self) { url in
                            Button { exportRecovery(url) } label: {
                                Label(url.deletingPathExtension().lastPathComponent, systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Backup & Restore").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .onAppear { recoveryFiles = AppBackupService.recoveryFiles() }
            .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in
                switch result {
                case .success: status = "Backup exported successfully."; error = nil
                case .failure(let failure): if (failure as NSError).code != NSUserCancelledError { error = failure.localizedDescription }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 20 * 1024 * 1024 else { throw AppBackupService.BackupError.tooLarge }
                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    preview = try AppBackupService.decode(data); error = nil
                } catch { if (error as NSError).code != NSUserCancelledError { self.error = error.localizedDescription } }
            }
            .confirmationDialog("Replace this app’s saved data?", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Restore Backup", role: .destructive) { restore() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("The selected backup replaces your current game, history, participants, drafts and photo catalogues. A recovery copy of the current data will be saved first. Your API key is unchanged.") }
        }
    }
    private var state: SavedGameState { SavedGameState(game: viewModel.game, savedGames: viewModel.savedGames) }
    private func exportCurrent() {
        do {
            let backup = try AppBackupService.make(state: state, participants: viewModel.masterPlayerList)
            exportDocument = BackupFileDocument(data: try AppBackupService.encode(backup))
            exportName = "Rugby Sweepstakes Backup " + Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
            exportType = .json; error = nil; showExporter = true
        } catch { self.error = "The backup could not be created. \(error.localizedDescription)" }
    }
    private func exportRecovery(_ url: URL) {
        do {
            exportDocument = BackupFileDocument(data: try Data(contentsOf: url))
            exportName = url.deletingPathExtension().lastPathComponent
            exportType = UTType(filenameExtension: url.pathExtension) ?? .data
            error = nil; showExporter = true
        } catch { self.error = error.localizedDescription }
    }
    private func restore() {
        guard let preview else { return }
        do {
            try AppBackupService.validate(preview)
            _ = try AppBackupService.recoveryFile(state: viewModel.storageWritesBlocked ? nil : state, participants: viewModel.masterPlayerList)
            try AppBackupService.apply(preview)
            viewModel.applyRestoredBackup(preview)
            TeamDraftStore.shared.reloadAfterRestore()
            PlayerPhotoLibrary.shared.reloadAfterRestore()
            self.preview = nil; error = nil; status = "Backup restored. Your previous data is kept in a recovery copy below."
            recoveryFiles = AppBackupService.recoveryFiles()
        } catch { self.error = "Restore could not be completed. \(error.localizedDescription)" }
    }
}
