import Foundation

/// Official club profile photo fallbacks, checked 2 November 2026.
/// Used only when the imported England squad has no photo for a full name.
enum PlayerPhotoCatalogue {
    static func assetName(named name: String) -> String? {
        switch EnglandPlayerNameMatcher.key(name) {
        case "maroitoje": "Portrait-Maro-Itoje"
        case "elliotdaly": "Portrait-Elliot-Daly"
        case "bevanrodd": "Portrait-Bevan-Rodd"
        default: nil
        }
    }

    static func url(named name: String) -> URL? {
        switch EnglandPlayerNameMatcher.key(name) {
        // Source: https://saracens.com/squads/maro-itoje/
        case "maroitoje": URL(string: "https://saracens.com/wp-content/uploads/2026/09/Shoot-folder0879-scaled-e1788270095395.jpg")
        // Source: https://saracens.com/squads/elliot-daly/
        case "elliotdaly": URL(string: "https://saracens.com/wp-content/uploads/2026/09/Shoot-folder0675-scaled-e1788268064477.jpg")
        // Source: https://www.quins.co.uk/profile/cadan-murley
        case "cadanmurley": URL(string: "https://images.ctfassets.net/r21395x2xyi6/48Tmy9InK1YMp4W0gVkpuk/9e0b4d7c81f76bca21c1d59f6d7c7f6b/Cadan_Murley_2.png?w=320&fm=png")
        // Source: https://www.salesharks.com/player/bevan-rodd/
        case "bevanrodd": URL(string: "https://www.salesharks.com/wp-content/uploads/2022/03/Bevan-Rodd-700x756-c-default.jpg")
        // Source: https://www.northamptonsaints.co.uk/player/29
        case "trevordavison": URL(string: "https://cdn.northamptonsaints.co.uk/sites/default/files/styles/cc_960x960/public/2026-09/82858%20Trevor%20Davison.png?h=c2b1d838&itok=Rt5xOzm4")
        // Source: https://www.bathrugby.com/teams/men/player/sam-underhill
        case "samunderhill": URL(string: "https://media-cdn.cortextech.io/NUCkxm4oBnib/1BSdBWIjCjnOS8/08235335-ebf4-42af-9d17-39fd9a5ed706.png?format=png&width=320")
        default: nil
        }
    }
}
