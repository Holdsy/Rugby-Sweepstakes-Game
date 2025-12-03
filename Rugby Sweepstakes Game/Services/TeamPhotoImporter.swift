//
//  TeamPhotoImporter.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation
import Vision
import UIKit

struct ExtractedPlayer {
    let number: Int?
    let name: String
}

class TeamPhotoImporter {
    
    static func extractPlayers(from image: UIImage) async -> [ExtractedPlayer] {
        guard let cgImage = image.cgImage else {
            return []
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        
        // Use accurate recognition for better results
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
            
            guard let observations = request.results else {
                return []
            }
            
            var extractedText: [String] = []
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                extractedText.append(topCandidate.string)
            }
            
            // Parse the extracted text to find player names and numbers
            return parsePlayers(from: extractedText.joined(separator: "\n"))
            
        } catch {
            print("Error performing text recognition: \(error)")
            return []
        }
    }
    
    private static func parsePlayers(from text: String) -> [ExtractedPlayer] {
        var players: [ExtractedPlayer] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }
            
            // Pattern matching for common formats:
            // "1. John Smith"
            // "1 John Smith"
            // "#1 John Smith"
            // "1 - John Smith"
            // "Jersey 1: John Smith"
            
            if let player = parsePlayerLine(trimmed) {
                players.append(player)
            }
        }
        
        return players
    }
    
    private static func parsePlayerLine(_ line: String) -> ExtractedPlayer? {
        // Remove common prefixes
        let cleaned = line
            .replacingOccurrences(of: "Jersey", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Number", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Try pattern: "1. Name" or "1 Name"
        if let match = cleaned.range(of: "^\\s*(\\d+)[.\\s\\-]+(.+)", options: .regularExpression) {
            let numberMatch = cleaned[cleaned.range(of: "^(\\d+)", options: .regularExpression)!]
            let nameStart = cleaned.index(match.lowerBound, offsetBy: String(numberMatch).count)
            let name = String(cleaned[nameStart...])
                .trimmingCharacters(in: CharacterSet(charactersIn: ".- "))
            
            if let number = Int(String(numberMatch)), !name.isEmpty {
                return ExtractedPlayer(number: number, name: name)
            }
        }
        
        // Try pattern: starts with number followed by name
        let components = cleaned.components(separatedBy: CharacterSet(charactersIn: ".- "))
            .filter { !$0.isEmpty }
        
        if components.count >= 2,
           let number = Int(components[0]),
           number > 0 && number <= 99 {
            let name = components[1...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                return ExtractedPlayer(number: number, name: name)
            }
        }
        
        // If no number found, try to extract just the name
        // Skip lines that look like headers or other text
        if cleaned.count > 2,
           !cleaned.lowercased().contains("team"),
           !cleaned.lowercased().contains("player"),
           !cleaned.lowercased().contains("squad"),
           !cleaned.matches("^\\d+$") { // Not just a number
            return ExtractedPlayer(number: nil, name: cleaned)
        }
        
        return nil
    }
}

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}

