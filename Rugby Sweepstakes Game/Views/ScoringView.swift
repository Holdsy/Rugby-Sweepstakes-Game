import SwiftUI

/// Retain existing navigation entry points while sharing the Match Day screen.
struct ScoringView: View {
    var body: some View { MatchDayView(initialSection: .score) }
}
