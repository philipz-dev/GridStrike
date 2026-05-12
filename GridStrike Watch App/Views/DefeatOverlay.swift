//
//  DefeatOverlay.swift
//  HQStrike Watch App
//
//  Lose path: full-bleed `defeatBackground`, title and subtitle vertically centered in the
//  lower third. Close control matches `DemoTopCloseButton` geometry (default offset).
//  Close advances to the setup map.
//

import SwiftUI

struct DefeatOverlay: View {
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geo in
            let lowerThird = geo.size.height / 3
            let bottomInset = max(geo.safeAreaInsets.bottom, 4)

            ZStack(alignment: .topLeading) {
                Color.black
                    .ignoresSafeArea()

                Assets.defeatBackground
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
                    VStack(alignment: .center, spacing: 6) {
                        Text("Defeat!")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.9), radius: 5, y: 2)
                        Text("The enemy destroyed your headquarter.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.85), radius: 3, y: 1)
                            .padding(.horizontal, 10)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
        .accessibilityLabel("Defeat")
        .accessibilityHint("Opens setup map.")
    }
}
