//
//  StartView.swift
//  HQStrike Watch App
//
//  Entry menu when `UIMode` is `.welcome`: (1) splash — `SplashBackground` + “Welcome to” /
//  “HQStrike!” — tap anywhere to continue. (2) Tactical hub — camo + “START / ASSAULT!”
//  and “FIELD / GUIDE”; guide opens `ManualWeaponsMenuView`; demos return to the hub.
//

import SwiftUI

struct StartView: View {
    /// Pushes the welcome title toward the chin: twice the old SF Symbol block (44 + 12) + 20.
    private static let splashTitleExtraTopInset: CGFloat = (44 + 12) * 2 + 50

    @Environment(GameStore.self) private var store
    /// After step (1); when true, shows the camo tactical menu (step 2).
    @State private var showTacticalMenu = false
    @State private var showManualWeaponsMenu = false
    @State private var showMissileDemo = false
    @State private var showCoastguardDemo = false
    @State private var showBomberDemo = false
    @State private var showGrenadeDemo = false

    var body: some View {
        ZStack {
            if showGrenadeDemo {
                Demo_Grenade(onClose: dismissDemoReturningToWeaponMenu)
            } else if showBomberDemo {
                Demo_Bomber(onClose: dismissDemoReturningToWeaponMenu)
            } else if showCoastguardDemo {
                Demo_Coastguard(onClose: dismissDemoReturningToWeaponMenu)
            } else if showMissileDemo {
                Demo_Missile(onClose: dismissDemoReturningToWeaponMenu)
            } else if showManualWeaponsMenu {
                ManualWeaponsMenuView(
                    onBack: {
                        showManualWeaponsMenu = false
                    },
                    onSelect: { selection in
                        showManualWeaponsMenu = false
                        showMissileDemo = false
                        showCoastguardDemo = false
                        showBomberDemo = false
                        showGrenadeDemo = false
                        switch selection {
                        case .grenade: showGrenadeDemo = true
                        case .missile: showMissileDemo = true
                        case .bomber: showBomberDemo = true
                        case .coastguard: showCoastguardDemo = true
                        }
                    }
                )
            } else {
                Group {
                    if showTacticalMenu {
                        mainMenuContent
                    } else {
                        splashContent
                    }
                }
            }
        }
        .onAppear {
            if store.state.welcomePresentStartMenu {
                showTacticalMenu = true
                store.send(.clearWelcomeStartMenuRequest)
            }
        }
    }

    // MARK: - Splash (first screen)

    private var splashContent: some View {
        ZStack {
            Assets.splashBackground
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, minHeight: 0)
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showTacticalMenu = true }

            VStack(spacing: 0) {
                Spacer()
                // Former splash: 44pt SF Symbol + 12pt gap above the title; title is offset
                // down by twice that block so it sits lower on the watch face.
                // Two separate outlined labels — multiline `Text` inside `OutlinedText`’s
                // ZStack mis-measures on watchOS and can hide the second line.
                VStack(spacing: 6) {
                    OutlinedText("Welcome to", font: .headline.weight(.bold))
                    OutlinedText("HQStrike!", font: .headline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.top, Self.splashTitleExtraTopInset)
                Spacer()
                    .frame(height: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Main menu (camo + tactical buttons)

    private var mainMenuContent: some View {
        ZStack {
            Assets.manualMenuCamouflage
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, minHeight: 0)
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                TacticalMainMenuButton(
                    line1: "START",
                    line2: "ASSAULT!",
                    innerFill: MainMenuStyle.startAssaultFill,
                    icon: .grenade
                ) {
                    store.send(.dismissWelcome)
                }
                .accessibilityLabel("Start game")

                TacticalMainMenuButton(
                    line1: "FIELD",
                    line2: "GUIDE",
                    innerFill: MainMenuStyle.darkCharcoal,
                    icon: .fieldGuide
                ) {
                    showManualWeaponsMenu = true
                }
                .accessibilityLabel("Guide")
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Ends any active scripted demo and shows the camouflage weapon hub again.
    private func dismissDemoReturningToWeaponMenu() {
        showGrenadeDemo = false
        showBomberDemo = false
        showCoastguardDemo = false
        showMissileDemo = false
        showManualWeaponsMenu = true
    }
}

// MARK: - Styling

private enum MainMenuStyle {
    /// Olive fill for START ASSAULT (asset corners are black; keep a readable green pill).
    static let startAssaultFill = Color(red: 58 / 255, green: 66 / 255, blue: 31 / 255)
    static let darkCharcoal = Color(red: 0.20, green: 0.21, blue: 0.23)
    /// Label copy on tactical buttons — larger than chrome padding so text dominates without growing the capsule much.
    static let tacticalTitleFont = Font.system(size: 15, weight: .heavy, design: .default)
}

// MARK: - Tactical button

private struct TacticalLabelHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TacticalMainMenuButton: View {
    enum IconKind {
        case grenade
        case fieldGuide
    }

    /// Matches `.padding(.vertical, 9)` on the inner row — icon square matches full label band height.
    private static let innerVerticalPaddingTotal: CGFloat = 18

    let line1: String
    let line2: String
    let innerFill: Color
    let icon: IconKind
    let action: () -> Void

    @State private var labelStackHeight: CGFloat = 0

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                iconSlot

                VStack(alignment: .leading, spacing: 0) {
                    Text(line1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(line2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .font(MainMenuStyle.tacticalTitleFont)
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TacticalLabelHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                )
            }
            .onPreferenceChange(TacticalLabelHeightPreferenceKey.self) { labelStackHeight = $0 }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 9)
            .background(innerFill)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.42), lineWidth: 1)
            )
            .padding(4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.52, green: 0.52, blue: 0.55),
                                Color(red: 0.28, green: 0.28, blue: 0.30),
                                Color(red: 0.42, green: 0.42, blue: 0.44)
                            ],
                            startPoint: UnitPoint(x: 0.15, y: 0),
                            endPoint: UnitPoint(x: 0.85, y: 1)
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .padding(2)
            )
            .overlay(rivetStrip)
        }
        .buttonStyle(.plain)
    }

    /// Icon height matches the two-line label stack + inner vertical padding (`.padding(.vertical, 9)` × 2).
    private var iconSlot: some View {
        Group {
            switch icon {
            case .grenade:
                Assets.startAssaultGrenade
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: tacticalIconSide, height: tacticalIconSide)
                    .accessibilityHidden(true)
            case .fieldGuide:
                Assets.mainMenuFieldGuide
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: tacticalIconSide, height: tacticalIconSide)
                    .accessibilityHidden(true)
            }
        }
    }

    private var tacticalIconSide: CGFloat {
        let fallback: CGFloat = 48
        guard labelStackHeight > 0 else { return fallback }
        let raw = labelStackHeight + Self.innerVerticalPaddingTotal
        return max(raw, 44)
    }

    /// Small rivet bumps along the outer metallic bezel.
    private var rivetStrip: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let rivet = Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.35), Color(white: 0.12)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 3
                    )
                )
                .frame(width: 4, height: 4)
                .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 0.5))

            ZStack {
                rivet.position(x: w * 0.12, y: h * 0.5)
                rivet.position(x: w * 0.28, y: h * 0.12)
                rivet.position(x: w * 0.50, y: h * 0.08)
                rivet.position(x: w * 0.72, y: h * 0.12)
                rivet.position(x: w * 0.88, y: h * 0.5)
                rivet.position(x: w * 0.72, y: h * 0.88)
                rivet.position(x: w * 0.50, y: h * 0.92)
                rivet.position(x: w * 0.28, y: h * 0.88)
            }
        }
        .allowsHitTesting(false)
    }
}
