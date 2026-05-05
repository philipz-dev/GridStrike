//
//  DefeatOverlay.swift
//  GridStrike Watch App
//
//  Shown when the opponent destroys the player's HQ — mirror of VictoryOverlay.
//

import SwiftUI

struct DefeatOverlay: View {
    let onNewGame: () -> Void
    let onShowMap: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Defeat")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 5, y: 2)
                Text("The enemy destroyed your headquarters.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 6)
                Button(action: onNewGame) {
                    Text("New game")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal, 8)
                Button(action: onShowMap) {
                    Text("Map")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.horizontal, 8)
            }
            .padding(16)
        }
        .allowsHitTesting(true)
    }
}
