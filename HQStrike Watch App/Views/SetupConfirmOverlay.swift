//
//  SetupConfirmOverlay.swift
//  HQStrike Watch App
//
//  After the player places their last unit, two equal-size circular actions appear
//  along the bottom: red ✗ restarts setup, green ✓ confirms. The board stays visible
//  underneath so the player can review the layout before committing.
//

import SwiftUI

struct SetupConfirmOverlay: View {
    let onRestart: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            VStack {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ZStack {
                        ConfirmCircleButton(
                            systemName: "xmark",
                            tint: .red,
                            action: onRestart
                        )
                        .accessibilityLabel("Restart setup")
                    }
                    .frame(maxWidth: .infinity)

                    ZStack {
                        ConfirmCircleButton(
                            systemName: "checkmark",
                            tint: .green,
                            action: onConfirm
                        )
                        .accessibilityLabel("Confirm setup")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Translucent circular setup actions — same diameter for cancel (✗) and confirm (✓).
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
