//
//  DemoTopCloseButton.swift
//  HQStrike Watch App
//
//  Shared top-leading × placement (weapon demos, manual, weapon hub, setup restart).
//  Leading padding + proportional top band + upward offset — same geometry everywhere.
//  All × art uses `TacticalCloseButton` (66% visual scale, unchanged 40×40 hit target app-wide).
//

import SwiftUI

/// Top-leading `TacticalCloseButton` stack: matches weapon demo trailers (not tied to ad-hoc per-screen padding).
struct TopLeadingTacticalCloseBar: View {
    static let leadingPadding: CGFloat = 8
    /// Default nudge toward the top (weapon demos / trailer overlays).
    static let defaultOffsetUp: CGFloat = 50
    /// Softer nudge for full-screen chrome (camo menus, manual) so the × stays on-screen and tappable.
    static let hubOffsetUp: CGFloat = 26

    let isVisible: Bool
    var style: TacticalCloseButton.Style = .standard
    let accessibilityLabel: String
    var accessibilityHint: String? = nil
    let screenHeight: CGFloat
    /// Vertical pull-up after proportional top padding; use `hubOffsetUp` on camo hubs so the control isn’t clipped.
    var upwardOffset: CGFloat = Self.defaultOffsetUp
    /// Additional downward shift (positive = lower on screen), e.g. Video guides hub.
    var extraDown: CGFloat = 0
    let action: () -> Void

    var body: some View {
        Group {
            if isVisible {
                HStack(alignment: .center, spacing: 0) {
                    TacticalCloseButton(
                        style: style,
                        accessibilityLabel: accessibilityLabel,
                        accessibilityHint: accessibilityHint,
                        action: action
                    )

                    Spacer(minLength: 0)
                }
                .padding(.leading, Self.leadingPadding)
                .padding(.top, Self.topPadding(screenHeight: screenHeight))
                .offset(y: -upwardOffset + extraDown)
                // Only the top row participates in hit testing so overlays don’t swallow the whole screen.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private static func topPadding(screenHeight: CGFloat) -> CGFloat {
        screenHeight * 0.06
    }

    /// Reserve space below the floating × so scroll content / titles don’t sit under the tap target.
    static func contentTopInsetClearance(
        screenHeight: CGFloat,
        upwardOffset: CGFloat = defaultOffsetUp,
        extraDown: CGFloat = 0
    ) -> CGFloat {
        let netTop = topPadding(screenHeight: screenHeight) - upwardOffset + extraDown
        return max(0, netTop) + TacticalCloseButton.tapTargetSide + 4
    }
}

/// Scripted demos: × appears only after the trailer ends.
struct DemoTopCloseButton: View {
    let isVisible: Bool
    let onClose: () -> Void
    /// Full viewport height from the demo `GeometryReader` (`.ignoresSafeArea()` backdrop).
    let screenHeight: CGFloat

    var body: some View {
        TopLeadingTacticalCloseBar(
            isVisible: isVisible,
            style: .standard,
            accessibilityLabel: "Close demo",
            accessibilityHint: "Returns to weapon menu",
            screenHeight: screenHeight,
            action: onClose
        )
    }
}
