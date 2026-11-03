import SwiftUI
import UIKit

/// Shared colours and surfaces, based on the rugby ball and gold ticket icon.
struct AppTheme {
    static let deepTeal = Color(red: 0, green: 0.22, blue: 0.22)
    static let teal = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.80, blue: 0.75, alpha: 1)
            : UIColor(red: 0, green: 0.34, blue: 0.33, alpha: 1)
    })
    static let gold = Color(red: 0.90, green: 0.68, blue: 0.25)
    static let winner = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.76, blue: 0.36, alpha: 1)
            : UIColor(red: 0.48, green: 0.32, blue: 0.06, alpha: 1)
    })
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.035, green: 0.09, blue: 0.09, alpha: 1)
            : UIColor(red: 0.94, green: 0.97, blue: 0.96, alpha: 1)
    })
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let primaryGradient = LinearGradient(
        colors: [deepTeal, Color(red: 0.04, green: 0.12, blue: 0.14)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

/// Retains the existing call sites while giving every screen the same calm surface.
struct LiquidGlassBackground: View {
    var body: some View { AppTheme.canvas.ignoresSafeArea() }
}

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.teal.opacity(0.12), lineWidth: 1)
            }
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .foregroundStyle(AppTheme.deepTeal)
            .background(AppTheme.gold.opacity(isEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : (isEnabled ? 1 : 0.6))
    }
}

extension View {
    func appListSurface() -> some View {
        self.scrollContentBackground(.hidden).background(AppTheme.canvas)
    }
    func appLiquidBackground() -> some View { self.background(LiquidGlassBackground()) }
    func appGlassNavigation(title: String) -> some View {
        self.navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
