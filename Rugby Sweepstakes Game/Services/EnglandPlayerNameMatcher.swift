import Foundation

/// Conservative full-name matching for the England photo catalogue.
/// Never infer identity from a surname or an approximate spelling alone.
enum EnglandPlayerNameMatcher {
    static func key(_ name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_GB"))
        let key = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
        // Verified provider/official-squad spelling difference.
        return key == "oliverchessum" ? "olliechessum" : key
    }

    static func index(named name: String, in names: [String]) -> Int? {
        let query = key(name)
        guard !query.isEmpty else { return nil }
        let matches = names.indices.filter { key(names[$0]) == query }
        return matches.count == 1 ? matches[0] : nil
    }
}
