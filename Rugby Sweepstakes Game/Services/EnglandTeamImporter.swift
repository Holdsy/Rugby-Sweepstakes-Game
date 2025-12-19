import Foundation

enum EnglandTeamImportError: LocalizedError {
    case invalidURL
    case unsupportedWebsite
    case blockedByWebsite
    case downloadFailed
    case noMatchdayTeam

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid England Rugby article link."
        case .unsupportedWebsite:
            return "For safety, only englandrugby.com articles can be imported."
        case .blockedByWebsite:
            return "England Rugby blocked the download. Open the article, copy its team list, and paste it here instead."
        case .downloadFailed:
            return "The article could not be downloaded. Check your connection or paste the team list instead."
        case .noMatchdayTeam:
            return "A complete numbered matchday team was not found. Paste the section containing players 1 to 23."
        }
    }
}

struct EnglandTeamImporter {
    static func players(fromArticleURL urlString: String) async throws -> [ExtractedPlayer] {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased() else {
            throw EnglandTeamImportError.invalidURL
        }

        guard host == "englandrugby.com" || host.hasSuffix(".englandrugby.com") else {
            throw EnglandTeamImportError.unsupportedWebsite
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EnglandTeamImportError.downloadFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnglandTeamImportError.downloadFailed
        }
        if httpResponse.statusCode == 403 {
            throw EnglandTeamImportError.blockedByWebsite
        }
        guard (200...299).contains(httpResponse.statusCode),
              let article = String(data: data, encoding: .utf8) else {
            throw EnglandTeamImportError.downloadFailed
        }

        return try players(from: article)
    }

    static func players(from articleText: String) throws -> [ExtractedPlayer] {
        let text = normalizedText(from: articleText)
        let pattern = #"(?m)^\s*(?:#\s*)?(\d{1,2})\s*[.):-]?\s+([\p{L}][\p{L}\p{M}'’\- ]{1,60}?)(?:\s*[–—-]\s*(?:captain|vice[- ]captain|vc|c))?\s*$"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(text.startIndex..., in: text)
        var playersByNumber: [Int: ExtractedPlayer] = [:]

        for match in regex.matches(in: text, range: range) {
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let nameRange = Range(match.range(at: 2), in: text),
                  let number = Int(text[numberRange]),
                  (1...23).contains(number) else {
                continue
            }

            let name = text[nameRange]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            playersByNumber[number] = ExtractedPlayer(number: number, name: name)
        }

        guard playersByNumber.keys.sorted() == Array(1...23) else {
            throw EnglandTeamImportError.noMatchdayTeam
        }

        return (1...23).compactMap { playersByNumber[$0] }
    }

    private static func normalizedText(from source: String) -> String {
        source
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</(?:p|li|h[1-6]|div)>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "’")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
