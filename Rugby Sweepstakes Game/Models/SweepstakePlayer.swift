//
//  SweepstakePlayer.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation
import SwiftUI

struct SweepstakePlayer: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: ColorData
    var assignedTeamMemberIds: [UUID]
    var drawRounds: [[Allocation]] // Allocations grouped by round
    
    init(
        id: UUID = UUID(),
        name: String,
        color: ColorData = ColorData.random(),
        assignedTeamMemberIds: [UUID] = [],
        drawRounds: [[Allocation]] = []
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.assignedTeamMemberIds = assignedTeamMemberIds
        self.drawRounds = drawRounds
    }
    
    // Computed property for total points - will be calculated in ViewModel
    var totalPoints: Int {
        // This is a placeholder - actual calculation happens in ViewModel
        // where we have access to team members
        return 0
    }
}

// Helper to encode/decode Color
struct ColorData: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    static func random() -> ColorData {
        let colors: [(Double, Double, Double)] = [
            (0.2, 0.6, 0.9),  // Blue
            (0.9, 0.2, 0.2),  // Red
            (0.2, 0.8, 0.3),  // Green
            (0.9, 0.7, 0.1),  // Yellow
            (0.7, 0.2, 0.8),  // Purple
            (1.0, 0.5, 0.0),  // Orange
        ]
        let randomColor = colors.randomElement() ?? (0.5, 0.5, 0.5)
        return ColorData(red: randomColor.0, green: randomColor.1, blue: randomColor.2)
    }
}

