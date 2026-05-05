//
//  HelpView.swift
//  GridStrike Watch App
//
//  In-app rules reference accessed via the `?` glyph on the welcome screen.
//  Styled to feel like an old handwritten letter on a parchment scroll —
//  the `Parchment` asset is the literal backdrop, sized to the watch width
//  and stretched vertically to fit the four sections (Goal / Setup / Combat /
//  Tactics) so the rules read as bite-sized chunks on the tiny display
//  rather than as one wall of text.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                goalCard
                setupCard
                combatCard
                tacticsCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Inset the text away from the rolled top/bottom curls and the
            // dark side shadows of the parchment scroll. The vertical pad is
            // generous so the first and last lines never collide with the
            // scroll caps even when the image stretches to fit long copy.
            .padding(.horizontal, 18)
            .padding(.top, 36)
            .padding(.bottom, 44)
            .font(.system(.body, design: .serif).italic())
            .foregroundStyle(LetterPalette.ink)
            .background {
                // Parchment stretches to match the natural content height —
                // the rolled scroll caps flex slightly with the text length,
                // which is acceptable on the watch and far simpler than the
                // 9-slice cap-inset variant.
                Assets.parchment
                    .resizable()
            }
        }
        .scrollIndicators(.hidden)
        // Outside the parchment we let the sheet sit on plain black so the
        // rolled edges of the scroll read against a void rather than the
        // system grey of the watchOS sheet chrome.
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("How to play")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(LetterPalette.ink)
            }
        }
    }

    // MARK: - Sections
    //
    // GroupBox isn't available on watchOS, so each section uses the
    // hand-rolled `LetterCard` container below — same visual intent
    // (titled paper insert) without depending on the unavailable API.

    /// First card the user reads — frames the rest of the manual by stating
    /// the win condition up front.
    private var goalCard: some View {
        LetterCard(title: "Goal") {
            Text("Destroy enemy headquarter!")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var setupCard: some View {
        LetterCard(title: "Setup") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Place objects:")
                unitLine(count: 1, name: "Headquarter")
                unitLine(count: 2, name: "Missiles")
                unitLine(count: 1, name: "Bomber")
                unitLine(count: 1, name: "Coastguard")
            }
        }
    }

    private var combatCard: some View {
        LetterCard(title: "Combat") {
            VStack(alignment: .leading, spacing: 8) {
                actionRow(
                    verb: "Grenade",
                    instruction: "Tap any tile",
                    damage: "1 tile damage"
                )
                actionRow(
                    verb: "Missile",
                    instruction: "Select missile, then tile",
                    damage: "5 tile X-shape damage"
                )
                actionRow(
                    verb: "Bomber",
                    instruction: "Select bomber, then tile",
                    damage: "3 tile damage"
                )
            }
        }
    }

    private var tacticsCard: some View {
        LetterCard(title: "Tactics") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Coastguard defends against missiles and bombers.")
                Text("Coastguards are vulnerable to grenades.")
            }
            // Multi-line copy needs `fixedSize` so it expands vertically inside
            // the card instead of clipping at a single line.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Row helpers

    /// Lines like "1×  Headquarter" — the count column is fixed-width so the
    /// unit names line up vertically into a tidy list.
    private func unitLine(count: Int, name: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(count)×")
                .monospacedDigit()
                .frame(minWidth: 20, alignment: .trailing)
            Text(name)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// Combat row — bold (non-italic) verb followed by the action, with the
    /// damage hint indented underneath in a smaller serif italic.
    private func actionRow(verb: String, instruction: String, damage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // `Text(verb).bold()` overrides the inherited italic so "Grenade"
            // / "Missile" / "Bomber" stand out as proper labels rather than
            // blending into the handwriting.
            (Text(verb).bold() + Text(": \(instruction)"))
                .fixedSize(horizontal: false, vertical: true)
            Text(damage)
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(LetterPalette.ink.opacity(0.78))
                .padding(.leading, 14)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Letter palette

/// Shared ink colour used by the help screen. The parchment background comes
/// from the `Parchment` asset directly, but we keep the ink centralised so
/// the toolbar Done button matches the body copy without drift.
private enum LetterPalette {
    /// Deep sepia — a "contrasting but old-look" colour that reads cleanly
    /// against the cream parchment scroll while still feeling hand-written
    /// in iron-gall ink rather than printer-black.
    static let ink = Color(red: 0.18, green: 0.09, blue: 0.03)
}

/// Lightweight stand-in for `GroupBox` (which is unavailable on watchOS).
/// On the parchment backdrop we deliberately drop the framed-paper look the
/// earlier gradient version used — a card-on-a-card would obscure the
/// scroll texture. Instead the section is signalled purely by the bold
/// serif italic title with a thin underline so the parchment stays visible
/// edge-to-edge.
private struct LetterCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.headline, design: .serif).weight(.bold))
                .italic()
                .foregroundStyle(LetterPalette.ink)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(LetterPalette.ink.opacity(0.45))
                        .frame(height: 0.5)
                        .offset(y: 4)
                }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
