//
//  TeamSetupView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct TeamSetupView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    var body: some View {
        Form {
            Section {
                Text("Starters: \(viewModel.game.starters.count)/15")
                    .font(.caption)
                    .foregroundColor(viewModel.game.starters.count == 15 ? .green : .orange)
            } header: {
                Text("Starters")
            } footer: {
                Text("Add exactly 15 starting players. Toggle to enable/disable players for the sweepstake.")
            }
            
            ForEach(viewModel.game.starters) { member in
                TeamMemberRow(
                    member: member,
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
            
            ForEach(viewModel.game.substitutes) { member in
                TeamMemberRow(
                    member: member,
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
    }
}

struct TeamMemberRow: View {
    let member: TeamMember
    let isStarter: Bool
    let availableSubstitutes: [TeamMember]
    let onUpdate: (TeamMember) -> Void
    var onToggleEnabled: (() -> Void)? = nil
    var onLinkSubstitute: ((UUID) -> Void)? = nil
    var onUnlinkSubstitute: (() -> Void)? = nil
    
    @State private var name: String
    @State private var position: String
    @State private var showSubstitutePicker = false
    
    init(
        member: TeamMember,
        isStarter: Bool,
        availableSubstitutes: [TeamMember],
        onUpdate: @escaping (TeamMember) -> Void,
        onToggleEnabled: (() -> Void)? = nil,
        onLinkSubstitute: ((UUID) -> Void)? = nil,
        onUnlinkSubstitute: (() -> Void)? = nil
    ) {
        self.member = member
        self.isStarter = isStarter
        self.availableSubstitutes = availableSubstitutes
        self.onUpdate = onUpdate
        self.onToggleEnabled = onToggleEnabled
        self.onLinkSubstitute = onLinkSubstitute
        self.onUnlinkSubstitute = onUnlinkSubstitute
        _name = State(initialValue: member.name)
        _position = State(initialValue: member.position ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: name) { _, newValue in
                    var updated = member
                    updated.name = newValue
                    onUpdate(updated)
                }
            
            TextField("Position (optional)", text: $position)
                .textFieldStyle(.roundedBorder)
                .onChange(of: position) { _, newValue in
                    var updated = member
                    updated.position = newValue.isEmpty ? nil : newValue
                    onUpdate(updated)
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

