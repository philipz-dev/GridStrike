//
//  TacticalCloseButton.swift
//  GridStrike Watch App
//
//  Shared 40×40 close / dismiss control — bold SF Symbol `xmark` for watchOS.
//  Artwork is drawn at `visualAppearanceScale` inside the tap target so the 40×40 hit area is unchanged app-wide.
//

import SwiftUI

struct TacticalCloseButton: View {
    /// Visual treatment: dark circle for dismiss/back, red circle for destructive confirm (e.g. restart setup).
    enum Style: Equatable {
        case standard
        case destructive
    }

    static let tapTargetSide: CGFloat = 40

    /// Circle + icon scale (1.0 = full `tapTargetSide`); shared by every × in the app.
    static let visualAppearanceScale: CGFloat = 0.66

    private static let iconPointSize: CGFloat = 19

    let style: Style
    let action: () -> Void
    let accessibilityLabel: String
    var accessibilityHint: String?

    init(
        style: Style = .standard,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.style = style
        self.action = action
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                ZStack {
                    switch style {
                    case .standard:
                        Circle()
                            .fill(Color.black.opacity(0.42))
                        Image(systemName: "xmark")
                            .font(.system(size: Self.iconPointSize, weight: .bold))
                            .foregroundStyle(.white)
                        Circle()
                            .stroke(Color.white.opacity(0.85), lineWidth: 1.25)
                    case .destructive:
                        Circle()
                            .fill(Color.red.opacity(0.22))
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.85), radius: 2, y: 1)
                        Circle()
                            .stroke(Color.red.opacity(0.95), lineWidth: 1.5)
                    }
                }
                .frame(width: Self.tapTargetSide, height: Self.tapTargetSide)
                .scaleEffect(Self.visualAppearanceScale)
            }
            .frame(width: Self.tapTargetSide, height: Self.tapTargetSide)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .modifier(OptionalAccessibilityHint(hint: accessibilityHint))
    }
}

private struct OptionalAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}
