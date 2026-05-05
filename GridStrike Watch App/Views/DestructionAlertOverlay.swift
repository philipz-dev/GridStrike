//
//  DestructionAlertOverlay.swift
//  GridStrike Watch App
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
            VStack(spacing: 10) {
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
                // Compact OK pill — natural-width, footnote-sized — so the
                // button never crowds the message.
                Button("OK", action: onDismiss)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .allowsHitTesting(true)
    }
}
