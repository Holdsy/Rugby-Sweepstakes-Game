//
//  StringExtensions.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation

extension String {
    func toTitleCase() -> String {
        // Split by spaces and capitalize each word
        let words = self.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        let titleCased = words.map { word -> String in
            // Handle empty strings
            guard !word.isEmpty else { return word }
            
            // Handle special cases like O'Connor, D'Angelo, etc.
            if word.contains("'") {
                let parts = word.components(separatedBy: "'")
                let capitalized = parts.map { part -> String in
                    guard !part.isEmpty else { return part }
                    return part.prefix(1).uppercased() + part.dropFirst().lowercased()
                }
                return capitalized.joined(separator: "'")
            }
            
            // Handle hyphenated names like Mary-Jane
            if word.contains("-") {
                let parts = word.components(separatedBy: "-")
                let capitalized = parts.map { part -> String in
                    guard !part.isEmpty else { return part }
                    return part.prefix(1).uppercased() + part.dropFirst().lowercased()
                }
                return capitalized.joined(separator: "-")
            }
            
            // Standard capitalization: first letter uppercase, rest lowercase
            return word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }
        
        return titleCased.joined(separator: " ")
    }
}

