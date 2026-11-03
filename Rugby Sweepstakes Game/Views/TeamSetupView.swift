//
//  TeamSetupView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct TeamSetupView: View {
    var showsDrawPreparation = true
    @EnvironmentObject var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showTeamReview = false
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
                            
                            Text(showsDrawPreparation ? "Review your rugby players and replacements." : "Name your starters and replacements. You’ll review draw exclusions later.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button { showTeamReview = true } label: {
                                Label("Finalise Team", systemImage: "person.3")
                            }

                            Button(role: .destructive) {
                                showResetConfirmation = true
                            } label: {
                                Label("Clear Team", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Label("Team Actions", systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Team actions")
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    if let importedAt = viewModel.englandSquadImportedAt {
                        Text("England squad last imported \(importedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    if showsDrawPreparation && viewModel.game.playersToDisableForEvenDraw > 0 {
                        let numberToDisable = viewModel.game.playersToDisableForEvenDraw

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Even out the draw", systemImage: "shuffle")
                                    .font(.headline)

                                Text(numberToDisable == 1
                                     ? "1 rugby player needs to be disabled so everyone receives the same number of players."
                                     : "\(numberToDisable) rugby players need to be disabled so everyone receives the same number of players.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Button {
                                    viewModel.disableRandomStartersForEvenDraw()
                                } label: {
                                    Label(
                                        numberToDisable == 1
                                            ? "Randomly Disable 1 Player"
                                            : "Randomly Disable \(numberToDisable) Players",
                                        systemImage: "dice"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                Text("Disabled players remain in the squad and can be re-enabled below.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: 24) {
                            // Starters section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Starters")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(viewModel.game.namedStarters.count)/15 named")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(viewModel.game.namedStarters.count == 15 ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                                        )
                                        .foregroundColor(viewModel.game.namedStarters.count == 15 ? .green : .orange)
                                }
                                
                                Text(showsDrawPreparation ? "Name all 15 starters. Disable anyone who should not be included in the draw." : "Name all 15 starters to continue setup.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 8) {
                                    ForEach(Array(viewModel.game.starters.enumerated()), id: \.element.id) { index, member in
                                        TeamMemberRow(
                                            member: member,
                                            shirtNumber: index + 1, // 1-15 for starters
                                            isStarter: true,
                                            showsDrawPreparation: showsDrawPreparation,
                                            availableSubstitutes: viewModel.game.substitutes,
                                            starters: viewModel.game.starters,
                                            squadPlayer: viewModel.englandSquadPlayer(named: member.name),
                                            availableSquadPlayers: viewModel.availableEnglandSquadPlayers(excluding: member.id),
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
                                            },
                                            onSelectSquadPlayer: { player in
                                                viewModel.assignEnglandPlayer(player, to: member.id)
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
                                    Text("\(viewModel.game.namedSubstitutes.count)/8 named")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(viewModel.game.namedSubstitutes.count == 8 ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                                        )
                                        .foregroundColor(viewModel.game.namedSubstitutes.count == 8 ? .green : .orange)
                                }
                                
                                Text("Substitute names are optional during setup. You can assign them while scoring.")
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
                                            squadPlayer: viewModel.englandSquadPlayer(named: member.name),
                                            availableSquadPlayers: viewModel.availableEnglandSquadPlayers(excluding: member.id),
                                            onUpdate: { updatedMember in
                                                viewModel.updateTeamMember(updatedMember)
                                            },
                                            onSelectSquadPlayer: { player in
                                                viewModel.assignEnglandPlayer(player, to: member.id)
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
        .sheet(isPresented: $showTeamReview) {
            CurrentTeamReviewView().environmentObject(viewModel)
        }
        .alert("Reset Team", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetTeam()
            }
        } message: {
            Text("Are you sure you want to clear all team information? This will remove all player names and cannot be undone.")
        }
    }
}


struct TeamMemberRow: View {
    let member: TeamMember
    let shirtNumber: Int
    let isStarter: Bool
    let showsDrawPreparation: Bool
    let availableSubstitutes: [TeamMember]
    let starters: [TeamMember]
    let squadPlayer: EnglandSquadPlayer?
    let availableSquadPlayers: [EnglandSquadPlayer]
    let onUpdate: (TeamMember) -> Void
    var onToggleEnabled: (() -> Void)? = nil
    var onLinkSubstitute: ((UUID) -> Void)? = nil
    var onUnlinkSubstitute: (() -> Void)? = nil
    var onSelectSquadPlayer: ((EnglandSquadPlayer?) -> Void)? = nil
    
    @State private var name: String
    @State private var showSubstitutePicker = false
    @State private var showEnglandPlayerPicker = false
    
    init(
        member: TeamMember,
        shirtNumber: Int,
        isStarter: Bool,
        showsDrawPreparation: Bool = true,
        availableSubstitutes: [TeamMember],
        starters: [TeamMember],
        squadPlayer: EnglandSquadPlayer? = nil,
        availableSquadPlayers: [EnglandSquadPlayer] = [],
        onUpdate: @escaping (TeamMember) -> Void,
        onToggleEnabled: (() -> Void)? = nil,
        onLinkSubstitute: ((UUID) -> Void)? = nil,
        onUnlinkSubstitute: (() -> Void)? = nil
        , onSelectSquadPlayer: ((EnglandSquadPlayer?) -> Void)? = nil
    ) {
        self.member = member
        self.shirtNumber = shirtNumber
        self.isStarter = isStarter
        self.showsDrawPreparation = showsDrawPreparation
        self.availableSubstitutes = availableSubstitutes
        self.starters = starters
        self.squadPlayer = squadPlayer
        self.availableSquadPlayers = availableSquadPlayers
        self.onUpdate = onUpdate
        self.onToggleEnabled = onToggleEnabled
        self.onLinkSubstitute = onLinkSubstitute
        self.onUnlinkSubstitute = onUnlinkSubstitute
        self.onSelectSquadPlayer = onSelectSquadPlayer
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
                
                if onSelectSquadPlayer != nil && !availableSquadPlayers.isEmpty {
                    Button {
                        showEnglandPlayerPicker = true
                    } label: {
                        EnglandPlayerSummary(player: squadPlayer, fallbackName: member.name)
                    }
                    .buttonStyle(.plain)
                } else {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { _, newValue in
                            var updated = member
                            updated.name = newValue
                            onUpdate(updated)
                        }
                }
            }
            
            if isStarter && showsDrawPreparation {
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
        .sheet(isPresented: $showEnglandPlayerPicker) {
            EnglandPlayerPickerView(
                players: availableSquadPlayers,
                currentPlayer: squadPlayer,
                onSelect: { player in
                    onSelectSquadPlayer?(player)
                    showEnglandPlayerPicker = false
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
                                    TeamMemberProfileView(member: substitute, imageSize: 36)
                                    
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
                                        TeamMemberProfileView(
                                            member: starter,
                                            imageSize: 26,
                                            namePrefix: "For #\(starterIndex + 1): "
                                        )
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
