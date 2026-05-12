//
//  VictoryOverlay.swift
//  HQStrike Watch App
//
//  End-of-game celebration: full-bleed `victoryBackground`, title vertically centered
//  in the lower third. Close control uses the same `GeometryReader` + overlay + `screenHeight`
//  math as `DemoTopCloseButton` (default upward offset). Close advances to the setup map.
//

import SwiftUI

struct VictoryOverlay: View {
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geo in
            let lowerThird = geo.size.height / 3
            let bottomInset = max(geo.safeAreaInsets.bottom, 4)

            ZStack(alignment: .topLeading) {
                Color.black
                    .ignoresSafeArea()

                Assets.victoryBackground
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text("Victory!")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.9), radius: 5, y: 2)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: lowerThird, alignment: .center)
                        .padding(.bottom, bottomInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                TopLeadingTacticalCloseBar(
                    isVisible: true,
                    accessibilityLabel: "Close",
                    accessibilityHint: "Opens setup map",
                    screenHeight: geo.size.height,
                    action: onContinue
                )
            }
        }
        .background(Color.black.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Victory")
        .accessibilityHint("Opens setup map.")
    }
}
