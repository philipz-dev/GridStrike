//
//  DestructionAlertOverlay.swift
//  HQStrike Watch App
//

import SwiftUI

struct DestructionAlertOverlay: View {
    /// The just-resolved attack we're announcing — both the attacker side and
    /// every unit it destroyed. The overlay renders one aggregated sentence
    /// from the right perspective ("Enemy missile destroyed!" /
    /// "Your 2 missiles and bomber are destroyed!") via the formatter on
    /// `Array<Unit>` — see `Unit.swift`.
    let alert: DestructionAlert
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
            // VStack fills the screen so the explicit Spacer below can push
            // the OK button toward the bottom edge instead of letting it ride
            // up against the message — multi-line destruction texts used to
            // hug the button so closely it visually clipped the last line.
            VStack(spacing: 0) {
                // ScrollView guarantees the full message is reachable even on
                // the smallest watch face — `.body` already fits the longest
                // expected sentence (~5 destroyed units), but a noisy
                // multi-attack queue or a future unit could push past the
                // viewport, in which case the user can scroll instead of
                // hitting an ellipsis.
                ScrollView(.vertical, showsIndicators: false) {
                    Text(alert.units.destroyedAlertMessage(attacker: alert.attacker))
                        // Body weight semibold reads as the modal title without
                        // ballooning past the OK button on 40 mm screens like
                        // .title3 did.
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.9), radius: 4, y: 2)
                        .frame(maxWidth: .infinity)
                }

                // Explicit gap between the message and the button — `minLength`
                // is the breathing-room minimum, the rest is consumed by the
                // VStack expanding to fill the screen.
                Spacer(minLength: 16)

                // Compact OK pill — natural-width, footnote-sized — so the
                // button never crowds the message. Bottom padding pulls it
                // off the curved watch bezel.
                Button("OK", action: onDismiss)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(true)
    }
}
