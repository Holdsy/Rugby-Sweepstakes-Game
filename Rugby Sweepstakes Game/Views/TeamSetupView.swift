//
//  TeamSetupView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct TeamSetupView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var extractedPlayers: [ExtractedPlayer] = []
    @State private var showImportReview = false
    @State private var isProcessingImage = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Starters: \(viewModel.game.starters.count)/15")
                        .font(.caption)
                        .foregroundColor(viewModel.game.starters.count == 15 ? .green : .orange)
                    
                    Spacer()
                    
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.caption)
                    }
                }
            } header: {
                Text("Starters")
            } footer: {
                Text("Add exactly 15 starting players. Toggle to enable/disable players for the sweepstake. Tap the photo icon to import team from a photo.")
            }
            
            ForEach(Array(viewModel.game.starters.enumerated()), id: \.element.id) { index, member in
                TeamMemberRow(
                    member: member,
                    shirtNumber: index + 1, // 1-15 for starters
                    isStarter: true,
                    availableSubstitutes: viewModel.game.substitutes,
                    onUpdate: { updatedMember in
                        viewModel.updateTeamMember(updatedMember)
                    },
                    onToggleEnabled: {
                        viewModel.toggleEnabledForGame(member.id)
                    },
                    onLinkSubstitute: { substituteId in
                        viewModel.linkSubstitute(substituteId: substituteId, to: member.id)
                    },
                    onUnlinkSubstitute: {
                        viewModel.unlinkSubstitute(from: member.id)
                    }
                )
            }
            
            Section {
                Text("Substitutes: \(viewModel.game.substitutes.count)/8")
                    .font(.caption)
                    .foregroundColor(viewModel.game.substitutes.count == 8 ? .green : .orange)
            } header: {
                Text("Substitutes")
            } footer: {
                Text("Add exactly 8 substitutes. You can link substitutes to starters.")
            }
            
            ForEach(Array(viewModel.game.substitutes.enumerated()), id: \.element.id) { index, member in
                TeamMemberRow(
                    member: member,
                    shirtNumber: index + 16, // 16-23 for substitutes
                    isStarter: false,
                    availableSubstitutes: [],
                    onUpdate: { updatedMember in
                        viewModel.updateTeamMember(updatedMember)
                    }
                )
            }
        }
        .navigationTitle("Team Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showResetConfirmation = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
        }
        .alert("Reset Team", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetTeam()
            }
        } message: {
            Text("Are you sure you want to clear all team information? This will remove all player names and cannot be undone.")
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView(selectedImage: $selectedImage) {
                showPhotoPicker = false
                if let image = selectedImage {
                    processImage(image)
                }
            }
        }
        .sheet(isPresented: $showImportReview) {
            TeamImportView(
                extractedPlayers: extractedPlayers,
                onImport: { players in
                    viewModel.importPlayers(players)
                    showImportReview = false
                    selectedImage = nil
                    extractedPlayers = []
                },
                onCancel: {
                    showImportReview = false
                    selectedImage = nil
                    extractedPlayers = []
                }
            )
        }
        .overlay {
            if isProcessingImage {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Extracting player information...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessingImage = true
        
        Task {
            let players = await TeamPhotoImporter.extractPlayers(from: image)
            
            await MainActor.run {
                isProcessingImage = false
                extractedPlayers = players
                if !players.isEmpty {
                    showImportReview = true
                }
            }
        }
    }
}

struct TeamMemberRow: View {
    let member: TeamMember
    let shirtNumber: Int
    let isStarter: Bool
    let availableSubstitutes: [TeamMember]
    let onUpdate: (TeamMember) -> Void
    var onToggleEnabled: (() -> Void)? = nil
    var onLinkSubstitute: ((UUID) -> Void)? = nil
    var onUnlinkSubstitute: (() -> Void)? = nil
    
    @State private var name: String
    @State private var showSubstitutePicker = false
    
    init(
        member: TeamMember,
        shirtNumber: Int,
        isStarter: Bool,
        availableSubstitutes: [TeamMember],
        onUpdate: @escaping (TeamMember) -> Void,
        onToggleEnabled: (() -> Void)? = nil,
        onLinkSubstitute: ((UUID) -> Void)? = nil,
        onUnlinkSubstitute: (() -> Void)? = nil
    ) {
        self.member = member
        self.shirtNumber = shirtNumber
        self.isStarter = isStarter
        self.availableSubstitutes = availableSubstitutes
        self.onUpdate = onUpdate
        self.onToggleEnabled = onToggleEnabled
        self.onLinkSubstitute = onLinkSubstitute
        self.onUnlinkSubstitute = onUnlinkSubstitute
        _name = State(initialValue: member.name)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("#\(shirtNumber)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(width: 35, alignment: .leading)
                
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { _, newValue in
                        var updated = member
                        updated.name = newValue
                        onUpdate(updated)
                    }
            }
            
            if isStarter {
                Toggle("Enabled for Game", isOn: Binding(
                    get: { member.isEnabledForGame },
                    set: { _ in onToggleEnabled?() }
                ))
                
                if let linkedSubstituteId = member.linkedSubstituteId,
                   let linkedSubstitute = availableSubstitutes.first(where: { $0.id == linkedSubstituteId }) {
                    HStack {
                        Text("Linked Substitute:")
                            .font(.caption)
                        Text(linkedSubstitute.name)
                            .font(.caption)
                            .foregroundColor(.blue)
                        Button("Unlink") {
                            onUnlinkSubstitute?()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button {
                        showSubstitutePicker = true
                    } label: {
                        Text("Link Substitute")
                            .font(.caption)
                    }
                    .disabled(availableSubstitutes.isEmpty)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showSubstitutePicker) {
            SubstitutePickerView(
                substitutes: availableSubstitutes,
                onSelect: { substituteId in
                    onLinkSubstitute?(substituteId)
                    showSubstitutePicker = false
                }
            )
        }
    }
}

struct SubstitutePickerView: View {
    let substitutes: [TeamMember]
    var currentLinkedSubstituteId: UUID? = nil
    let onSelect: (UUID) -> Void
    var onUnlink: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            List {
                if currentLinkedSubstituteId != nil,
                   onUnlink != nil {
                    Section {
                        Button(role: .destructive) {
                            onUnlink?()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Unlink Current Substitute")
                            }
                        }
                    }
                }
                
                Section {
                    ForEach(substitutes) { substitute in
                        Button {
                            onSelect(substitute.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(substitute.name.isEmpty ? "Unnamed Substitute" : substitute.name)
                                        .foregroundColor(.primary)
                                    if let position = substitute.position {
                                        Text(position)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if substitute.id == currentLinkedSubstituteId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Substitute")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        TeamSetupView()
            .environmentObject(GameViewModel())
    }
}

