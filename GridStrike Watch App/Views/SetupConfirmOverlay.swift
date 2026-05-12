//
//  SetupConfirmOverlay.swift
//  GridStrike Watch App
//
//  Two translucent buttons that appear after the player places their last
//  unit. The board renders normally underneath so the player can review their
//  layout — the red ✗ wipes the board and rewinds setup, the green ✓ commits
//  the layout and starts the round.
//

import SwiftUI

struct SetupConfirmOverlay: View {
    let onRestart: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                TopLeadingTacticalCloseBar(
                    isVisible: true,
                    style: .destructive,
                    accessibilityLabel: "Restart setup",
                    screenHeight: geo.size.height,
                    upwardOffset: TopLeadingTacticalCloseBar.hubOffsetUp,
                    action: onRestart
                )

                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        ConfirmCircleButton(
                            systemName: "checkmark",
                            tint: .green,
                            action: onConfirm
                        )
                        .accessibilityLabel("Confirm setup")
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Translucent circular button for the green ✓ only. The red ✗ uses `TacticalCloseButton` (destructive style).
private struct ConfirmCircleButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    private static let diameter: CGFloat = 42

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.32))
                Circle()
                    .stroke(tint.opacity(0.95), lineWidth: 1.5)
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.85), radius: 2, y: 1)
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
