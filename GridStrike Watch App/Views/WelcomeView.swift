//
//  WelcomeView.swift
//  GridStrike Watch App
//

import SwiftUI

struct WelcomeView: View {
    @Environment(GameStore.self) private var store
    @State private var showHelp = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background visuals — purely decorative, hit-testing is disabled
            // so taps fall through to the dedicated dismiss layer below.
            // The previous black-dim overlay has been removed; the title text
            // gets its own black outline below for legibility against the
            // raw splash artwork instead.
            Assets.splashBackground
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, minHeight: 0)
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Tap-anywhere-to-start surface. Sits below the help button in the
            // ZStack so the button consumes its own taps; everywhere else
            // routes through here and dispatches `.dismissWelcome`.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { store.send(.dismissWelcome) }

            // Welcome label pinned to the bottom — also non-interactive so it
            // doesn't swallow the tap-to-start gesture above. Outlined in
            // black via stacked offset copies so the white fill stays
            // legible on any region of the splash.
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

            // `?` glyph anchored to the very top-left corner. Bigger than the
            // previous icon (28 pt) so it's an obvious affordance, with
            // padding pulled all the way down so it sits flush against the
            // safe-area edge. Buttons consume taps inside their bounds, so
            // the dismiss gesture only fires when the user taps elsewhere.
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
            .padding(.top, 0)
            .accessibilityLabel("How to play")
        }
        .sheet(isPresented: $showHelp) {
            // NavigationStack supplies the inline title bar + toolbar slot for
            // the Done button, and lets the sheet present as a proper modal
            // page instead of just bare scroll content.
            NavigationStack {
                HelpView()
            }
        }
    }
}

/// White text crisply outlined in black for use over a busy photographic
/// background. Built from a ZStack of eight offset copies of the label
/// (one per compass direction) drawn in the outline colour, with the fill
/// version drawn on top — gives a hard, even border at any font size,
/// unlike a soft `.shadow` which would smear.
private struct OutlinedText: View {
    let content: String
    let font: Font
    var fill: Color = .white
    var outline: Color = .black
    var outlineWidth: CGFloat = 1

    init(_ content: String, font: Font) {
        self.content = content
        self.font = font
    }

    var body: some View {
        ZStack {
            outlineLayer(dx: -1, dy: -1)
            outlineLayer(dx:  0, dy: -1)
            outlineLayer(dx:  1, dy: -1)
            outlineLayer(dx: -1, dy:  0)
            outlineLayer(dx:  1, dy:  0)
            outlineLayer(dx: -1, dy:  1)
            outlineLayer(dx:  0, dy:  1)
            outlineLayer(dx:  1, dy:  1)
            Text(content).foregroundStyle(fill)
        }
        .font(font)
    }

    private func outlineLayer(dx: CGFloat, dy: CGFloat) -> some View {
        Text(content)
            .foregroundStyle(outline)
            .offset(x: dx * outlineWidth, y: dy * outlineWidth)
    }
}
