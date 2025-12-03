//
//  DesignSystem.swift
//  Rugby Sweepstakes Game
//
//  A lightweight design system to give the app a modern, glass / liquid look
//  while remaining compatible with current iOS SwiftUI APIs.
//

import SwiftUI

// MARK: - Colors & Gradients

struct AppTheme {
    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.22, blue: 0.55),
            Color(red: 0.05, green: 0.40, blue: 0.85),
            Color(red: 0.03, green: 0.62, blue: 0.78)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.25),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Backgrounds

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            AppTheme.primaryGradient
                .ignoresSafeArea()
            
            // Soft bokeh-like blobs for depth
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: -140, y: -260)
            
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: 160, y: 120)
        }
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                Color.white.opacity(0.35),
                                lineWidth: 1
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - View Helpers

extension View {
    /// Applies the app's default "liquid glass" background.
    func appLiquidBackground() -> some View {
        self.background(LiquidGlassBackground())
    }
    
    /// Styles navigation bars with a translucent, modern appearance where available.
    func appGlassNavigation(title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}


