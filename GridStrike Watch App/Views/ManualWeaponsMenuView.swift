//
//  ManualWeaponsMenuView.swift
//  GridStrike Watch App
//
//  Full-screen camouflage with a 2×2 weapon picker (Grenade, Missile, Bomber, Coastguard).
//

import SwiftUI

struct ManualWeaponsMenuView: View {
    enum Selection {
        case grenade
        case missile
        case bomber
        case coastguard
    }

    let onBack: () -> Void
    let onSelect: (Selection) -> Void

    /// Horizontal fine-tune vs camouflage template squares.
    private static let gridNudgeX: CGFloat = 0

    /// Soft max; layout picks `min(targetIconSize, width, height slots)`.
    private static let targetIconSize: CGFloat = 128

    private static let cellCornerRadius: CGFloat = 18
    private static let gridSpacing: CGFloat = 8

    private static let cellPadding: CGFloat = 5

    /// Title between the × row and weapon tiles.
    private static let guideTitleTopPadding: CGFloat = 4
    /// Matches the gradient band height used for Guide title layout reserve.
    private static let guideTitleBlockHeight: CGFloat = 34

    /// Space below the Guide title before the 2×2 grid.
    private static let gridTopInsetBelowTopBar: CGFloat = 8

    /// Touch target row height for top controls (aligned with system time band).
    private static let topBarRowHeight: CGFloat = 32

    /// Full-width band behind the Guide title (black → clear, bottom-heavy).
    private static let guideTitleGradientHeight: CGFloat = guideTitleBlockHeight

    /// Black fading upward behind weapon labels (fraction of icon height).
    private static let weaponLabelGradientHeightFactor: CGFloat = 0.42

    private static var guideTitleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.44),
                Color.black.opacity(0.18),
                Color.clear,
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    var body: some View {
        GeometryReader { geo in
            let topReserved =
                geo.safeAreaInsets.top + Self.topBarRowHeight
                + Self.guideTitleTopPadding + Self.guideTitleBlockHeight
                + Self.gridTopInsetBelowTopBar
            let bottomReserved = geo.safeAreaInsets.bottom + 4

            let widthSlot = (geo.size.width - 12 - Self.gridSpacing) / 2 - 4
            let usableHeight = geo.size.height - topReserved - bottomReserved
            let heightSlot = (usableHeight - Self.gridSpacing) / 2 - Self.cellPadding * 2
            let iconSide = min(
                Self.targetIconSize,
                max(44, min(widthSlot, heightSlot))
            )

            ZStack {
                Assets.manualMenuCamouflage
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, geo.safeAreaInsets.top)
                        .padding(.horizontal, 8)

                    ZStack {
                        Self.guideTitleGradient
                            .frame(maxWidth: .infinity)
                            .frame(height: Self.guideTitleGradientHeight)

                        Text("Guide")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Self.guideTitleTopPadding)

                    grid(iconSide: iconSide)
                        .frame(width: geo.size.width * 0.94)
                        .padding(.top, Self.gridTopInsetBelowTopBar)
                        .offset(x: Self.gridNudgeX)

                    Spacer(minLength: 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    /// Dismiss × on the leading edge, aligned with the watch time row.
    private var topBar: some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                onBack()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                    .frame(width: Self.topBarRowHeight, height: Self.topBarRowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to Start game and Guide menu")

            Spacer(minLength: 0)
        }
        .frame(height: Self.topBarRowHeight)
    }

    private func grid(iconSide: CGFloat) -> some View {
        VStack(spacing: Self.gridSpacing) {
            HStack(spacing: Self.gridSpacing) {
                weaponCell(icon: Assets.manualMenuGrenade, title: "Grenade", iconSide: iconSide) {
                    onSelect(.grenade)
                }
                weaponCell(icon: Assets.manualMenuMissile, title: "Missile", iconSide: iconSide) {
                    onSelect(.missile)
                }
            }
            HStack(spacing: Self.gridSpacing) {
                weaponCell(icon: Assets.manualMenuBomber, title: "Bomber", iconSide: iconSide) {
                    onSelect(.bomber)
                }
                weaponCell(icon: Assets.manualMenuCoastguard, title: "Coastguard", iconSide: iconSide) {
                    onSelect(.coastguard)
                }
            }
        }
    }

    private func weaponCell(
        icon: Image,
        title: String,
        iconSide: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        let labelFontSize = min(22, max(11, iconSide * 0.24))
        let labelBandHeight = max(36, iconSide * Self.weaponLabelGradientHeightFactor)

        return Button(action: action) {
            ZStack(alignment: .bottom) {
                icon
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: iconSide, height: iconSide)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.26),
                        Color.black.opacity(0.52),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: labelBandHeight)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

                OutlinedText(
                    title,
                    font: .system(size: labelFontSize, weight: .semibold, design: .rounded),
                    fill: .white,
                    outline: .black,
                    outlineWidth: 1.25
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: iconSide + 4)
                .padding(.horizontal, 4)
                .padding(.bottom, 5)
            }
            .padding(Self.cellPadding)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Self.cellCornerRadius))
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    ManualWeaponsMenuView(onBack: {}, onSelect: { _ in })
}
#endif
