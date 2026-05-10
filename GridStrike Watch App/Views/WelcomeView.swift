//
//  WelcomeView.swift
//  GridStrike Watch App
//
//  First screen: splash artwork with the `?` help glyph in the top-left.
//  Tapping anywhere reveals a small in-place menu with two choices —
//  "Start game" (begins setup) and "Manual" (swaps to the manual inline).
//
//  Manual is presented inline (not via `.fullScreenCover`) so the OS doesn't
//  layer a system close chrome on top of our own X. The manual's own X is
//  the single close affordance and it routes straight into setup so the
//  player never has to tap "Start game" separately after reading the rules.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(GameStore.self) private var store
    @State private var showHelp = false
    @State private var showManual = false
    @State private var showStartMenu = false
    @State private var showMissileDemo = false
    @State private var showBomberDemo = false

    var body: some View {
        ZStack {
            if showBomberDemo {
                Demo_Bomber(onClose: { showBomberDemo = false })
            } else if showMissileDemo {
                Demo_Missile(onClose: { showMissileDemo = false })
            } else if showManual {
                // Inline presentation — no `.fullScreenCover`, so no system
                // close button is layered on top of the manual's own X.
                ManualView(onClose: {
                    showManual = false
                    showStartMenu = false
                    store.send(.dismissWelcome)
                })
            } else {
                splashContent
            }
        }
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                HelpView()
            }
        }
    }

    // MARK: - Splash

    private var splashContent: some View {
        ZStack(alignment: .topLeading) {
            Assets.splashBackground
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, minHeight: 0)
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Tap-anywhere surface — first tap reveals the start menu.
            // Once the menu is up, taps inside the menu's buttons take
            // precedence; taps outside dismiss the menu (handled by the
            // menu overlay's own background).
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showStartMenu = true }

            VStack {
                Spacer()
                OutlinedText(
                    "Welcome to GridStrike!",
                    font: .headline.weight(.bold)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .padding(.top, 0)
            .offset(y: -20)
            .accessibilityLabel("How to play")

            // Small O buttons for scripted demos (screen recording).
            VStack(spacing: 6) {
                Button {
                    showBomberDemo = false
                    showMissileDemo = true
                } label: {
                    Text("O")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play missile demo")

                Button {
                    showMissileDemo = false
                    showBomberDemo = true
                } label: {
                    Text("O")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play bomber demo")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 4)
            .padding(.top, 0)
            .offset(y: -20)
        }
        .overlay {
            if showStartMenu {
                startMenuOverlay
            }
        }
    }

    /// Two-button choice screen revealed by the first tap on the splash.
    /// Background is fully opaque so the splash artwork is hidden — the menu
    /// reads as its own dedicated screen rather than a translucent overlay.
    private var startMenuOverlay: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                // Tap outside the buttons returns to the splash. The buttons
                // sit on top of this layer so their hits don't fall through.
                .onTapGesture { showStartMenu = false }

            VStack(spacing: 10) {
                Button {
                    showStartMenu = false
                    store.send(.dismissWelcome)
                } label: {
                    Text("Start game")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(EndGamePalette.mutedGreen)

                Button {
                    showStartMenu = false
                    showManual = true
                } label: {
                    Text("Manual")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(EndGamePalette.mutedGray)
            }
            .padding(.horizontal, 14)
        }
        .transition(.opacity)
    }
}

// `OutlinedText` lives in its own file (`OutlinedText.swift`) so the help
// screen header can reuse the same crisp black-edged label without the
// type having to live as a `private` helper inside the welcome view.
