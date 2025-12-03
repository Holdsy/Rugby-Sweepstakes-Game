//
//  TeamImportView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct TeamImportView: View {
    let extractedPlayers: [ExtractedPlayer]
    let onImport: ([ExtractedPlayer]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedPlayers: Set<Int> = Set()
    @State private var editedPlayers: [Int: String] = [:]
    @State private var editedNumbers: [Int: Int?] = [:]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()
                
                List {
                    if extractedPlayers.isEmpty {
                        Section {
                            Text("No players were detected in the image. Please try again with a clearer photo.")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Section {
                            Text("Review and edit the extracted players. Select which players to import as starters.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Section {
                            ForEach(Array(extractedPlayers.enumerated()), id: \.offset) { index, player in
                                PlayerImportRow(
                                    player: player,
                                    isSelected: selectedPlayers.contains(index),
                                    editedName: editedPlayers[index] ?? player.name,
                                    editedNumber: editedNumbers[index] ?? player.number,
                                    onToggle: {
                                        if selectedPlayers.contains(index) {
                                            selectedPlayers.remove(index)
                                        } else {
                                            selectedPlayers.insert(index)
                                        }
                                    },
                                    onNameChange: { newName in
                                        editedPlayers[index] = newName
                                    },
                                    onNumberChange: { newNumber in
                                        editedNumbers[index] = newNumber
                                    }
                                )
                            }
                        } header: {
                            Text("Detected Players (\(extractedPlayers.count))")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Import Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        let playersToImport = selectedPlayers.compactMap { index -> ExtractedPlayer? in
                            let original = extractedPlayers[index]
                            let name = editedPlayers[index] ?? original.name
                            let number = editedNumbers[index] ?? original.number
                            return ExtractedPlayer(number: number, name: name)
                        }
                        onImport(playersToImport)
                    }
                    .disabled(selectedPlayers.isEmpty)
                }
            }
        }
    }
}

struct PlayerImportRow: View {
    let player: ExtractedPlayer
    let isSelected: Bool
    let editedName: String
    let editedNumber: Int?
    let onToggle: () -> Void
    let onNameChange: (String) -> Void
    let onNumberChange: (Int?) -> Void
    
    @State private var nameText: String
    @State private var numberText: String
    
    init(
        player: ExtractedPlayer,
        isSelected: Bool,
        editedName: String,
        editedNumber: Int?,
        onToggle: @escaping () -> Void,
        onNameChange: @escaping (String) -> Void,
        onNumberChange: @escaping (Int?) -> Void
    ) {
        self.player = player
        self.isSelected = isSelected
        self.editedName = editedName
        self.editedNumber = editedNumber
        self.onToggle = onToggle
        self.onNameChange = onNameChange
        self.onNumberChange = onNumberChange
        _nameText = State(initialValue: editedName)
        _numberText = State(initialValue: editedNumber.map { String($0) } ?? "")
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // Editable shirt number field
            HStack(spacing: 4) {
                Text("#")
                    .font(.headline)
                    .foregroundColor(.secondary)
                TextField("?", text: $numberText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 55)
                    .onChange(of: numberText) { _, newValue in
                        // Only allow numeric input
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            numberText = filtered
                        }
                        // Update the number (nil if empty)
                        if filtered.isEmpty {
                            onNumberChange(nil)
                        } else if let number = Int(filtered), number > 0 && number <= 99 {
                            onNumberChange(number)
                        }
                    }
            }
            .frame(width: 75, alignment: .leading)
            
            TextField("Player Name", text: $nameText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: nameText) { _, newValue in
                    onNameChange(newValue)
                }
        }
    }
}

