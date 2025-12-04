//
//  TeamSetupView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct TeamSetupView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var extractedPlayers: [ExtractedPlayer] = []
    @State private var showImportReview = false
    @State private var isProcessingImage = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Match HomeView title style
                    HStack(spacing: 8) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Team Setup")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("Add starters and substitutes, then link them for in‑game substitutions.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Import team from photo")
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: 24) {
                            // Starters section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Starters")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(viewModel.game.starters.count)/15")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(viewModel.game.starters.count == 15 ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                                        )
                                        .foregroundColor(viewModel.game.starters.count == 15 ? .green : .orange)
                                }
                                
                                Text("Add exactly 15 starting players. Toggle to enable/disable players for the sweepstake.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 8) {
                                    ForEach(Array(viewModel.game.starters.enumerated()), id: \.element.id) { index, member in
                                        TeamMemberRow(
                                            member: member,
                                            shirtNumber: index + 1, // 1-15 for starters
                                            isStarter: true,
                                            availableSubstitutes: viewModel.game.substitutes,
                                            starters: viewModel.game.starters,
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
                                }
                            }
                            
                            Divider()
                            
                            // Substitutes section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Substitutes")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(viewModel.game.substitutes.count)/8")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(viewModel.game.substitutes.count == 8 ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                                        )
                                        .foregroundColor(viewModel.game.substitutes.count == 8 ? .green : .orange)
                                }
                                
                                Text("Add exactly 8 substitutes. You can link substitutes to starters.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 8) {
                                    ForEach(Array(viewModel.game.substitutes.enumerated()), id: \.element.id) { index, member in
                                        TeamMemberRow(
                                            member: member,
                                            shirtNumber: index + 16, // 16-23 for substitutes
                                            isStarter: false,
                                            availableSubstitutes: [],
                                            starters: viewModel.game.starters,
                                            onUpdate: { updatedMember in
                                                viewModel.updateTeamMember(updatedMember)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 24)
                }
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
    let starters: [TeamMember]
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
        starters: [TeamMember],
        onUpdate: @escaping (TeamMember) -> Void,
        onToggleEnabled: (() -> Void)? = nil,
        onLinkSubstitute: ((UUID) -> Void)? = nil,
        onUnlinkSubstitute: (() -> Void)? = nil
    ) {
        self.member = member
        self.shirtNumber = shirtNumber
        self.isStarter = isStarter
        self.availableSubstitutes = availableSubstitutes
        self.starters = starters
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
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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
                starters: starters,
                currentLinkedSubstituteId: member.linkedSubstituteId,
                onSelect: { substituteId in
                    onLinkSubstitute?(substituteId)
                    showSubstitutePicker = false
                },
                onUnlink: {
                    onUnlinkSubstitute?()
                    showSubstitutePicker = false
                }
            )
        }
    }
}

struct SubstitutePickerView: View {
    let substitutes: [TeamMember]
    let starters: [TeamMember]
    var currentLinkedSubstituteId: UUID? = nil
    let onSelect: (UUID) -> Void
    var onUnlink: (() -> Void)? = nil
    
    // Get shirt number for a substitute (16-23 based on index)
    private func getShirtNumber(for substitute: TeamMember) -> Int {
        if let index = substitutes.firstIndex(where: { $0.id == substitute.id }) {
            return index + 16
        }
        // Fallback: try to extract from position field
        if let position = substitute.position,
           let range = position.range(of: "\\d+", options: .regularExpression),
           let number = Int(String(position[range])) {
            return number
        }
        return 0
    }
    
    // Find which starter this substitute is linked to
    private func getSubstitutedFor(for substitute: TeamMember) -> TeamMember? {
        starters.first { starter in
            starter.linkedSubstituteId == substitute.id
        }
    }
    
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
                    ForEach(Array(substitutes.enumerated()), id: \.element.id) { index, substitute in
                        let shirtNumber = index + 16
                        let substitutedFor = getSubstitutedFor(for: substitute)
                        
                        Button {
                            onSelect(substitute.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("#\(shirtNumber)")
                                        .font(.headline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    Text(substitute.name.isEmpty ? "Unnamed Substitute" : substitute.name)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if substitute.id == currentLinkedSubstituteId {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                if let starter = substitutedFor,
                                   let starterIndex = starters.firstIndex(where: { $0.id == starter.id }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text("Substitutes for #\(starterIndex + 1) \(starter.name)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
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

