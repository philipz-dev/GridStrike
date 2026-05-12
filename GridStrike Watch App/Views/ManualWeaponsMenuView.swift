//
//  ManualWeaponsMenuView.swift
//  HQStrike Watch App
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
    /// Gap between cells (both axes). Kept tight on purpose: with the
    /// previous `8`, the slot-fit icons (~+20% target) overflowed the
    /// bottom of the watch screen. Trimming the gap reclaims that
    /// vertical room so two rows fit without an explicit scale factor.
    private static let gridSpacing: CGFloat = 3

    /// Inner padding inside each weapon cell. Reduced from `5` for the
    /// same reason as `gridSpacing` — frees vertical room so the icon
    /// (sized off `heightSlot`) doesn't push past the bottom safe area.
    private static let cellPadding: CGFloat = 2

    /// Pushes only the top-leading × lower; title/grid clearance stays the pre-nudge layout so icons stay large.
    private static let videoGuideCloseExtraDown: CGFloat = 25

    /// Title between the × row and weapon tiles.
    private static let guideTitleTopPadding: CGFloat = 4
    /// Matches the gradient band height used for the “Video guides” title layout reserve.
    private static let guideTitleBlockHeight: CGFloat = 34

    /// Same size as the title `Text` below — used to nudge title + grid upward so they clear the bottom bezel.
    private static let guideTitleFontSize: CGFloat = 18

    /// Approximate line height for the title at `guideTitleFontSize` on watch.
    private static let guideTitleFontLineHeight: CGFloat = 22

    /// Space below the title before the 2×2 grid.
    private static let gridTopInsetBelowTopBar: CGFloat = 8

    /// Full-width band behind the title (black → clear, bottom-heavy).
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
            let closeUp = TopLeadingTacticalCloseBar.hubOffsetUp
            let closeDown = Self.videoGuideCloseExtraDown
            let topReserved =
                geo.safeAreaInsets.top
                + TopLeadingTacticalCloseBar.contentTopInsetClearance(
                    screenHeight: geo.size.height,
                    upwardOffset: closeUp
                )
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

            ZStack(alignment: .topLeading) {
                Assets.manualMenuCamouflage
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ZStack {
                            Self.guideTitleGradient
                                .frame(maxWidth: .infinity)
                                .frame(height: Self.guideTitleGradientHeight)

                            Text("Video guides")
                                .font(.system(size: Self.guideTitleFontSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(
                            .top,
                            geo.safeAreaInsets.top
                                + TopLeadingTacticalCloseBar.contentTopInsetClearance(
                                    screenHeight: geo.size.height,
                                    upwardOffset: closeUp
                                )
                                + Self.guideTitleTopPadding
                        )

                        grid(iconSide: iconSide)
                            .frame(width: geo.size.width * 0.94)
                            .padding(.top, Self.gridTopInsetBelowTopBar)
                            .offset(x: Self.gridNudgeX)
                    }
                    .offset(y: -Self.guideTitleFontLineHeight)

                    Spacer(minLength: 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topLeading) {
                TopLeadingTacticalCloseBar(
                    isVisible: true,
                    accessibilityLabel: "Back",
                    accessibilityHint: "Returns to Start game and tactical menu",
                    screenHeight: geo.size.height,
                    upwardOffset: closeUp,
                    extraDown: closeDown,
                    action: onBack
                )
            }
        }
        .ignoresSafeArea()
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
