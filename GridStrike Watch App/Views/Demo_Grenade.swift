//
//  Demo_Grenade.swift
//  GridStrike Watch App
//
//  Grenade trailer: hand at row 12 col 2; 1s hold on that frame, then scroll to row 3 col 2; 0.3s after arrival the orange outline appears on
//  the tapped tile (hand stays through outline dwell); yellow hit explosion (50% → 200% → 100% scale pulse) on a missile tile, then the hand hides;
//  (home `demoMissile2` clears the same way the home bomber clears in Demo_Missile), then 1s later "Missile eliminated!".
//

import SwiftUI
import WatchKit

struct Demo_Grenade: View {
    let onClose: () -> Void

    private static let bottomCurveTapReserve: CGFloat = 10
    private static let handSize: CGFloat = 48
    private static let initialHandExtraOffsetY: CGFloat = 50

    /// Same board unit marks as the other scripted demos.
    private static let demoHQ = GridPosition(10, 3)
    private static let demoMissile1 = GridPosition(11, 0)
    private static let demoMissile2 = GridPosition(9, 1)
    private static let demoBomber = GridPosition(12, 2)
    private static let demoCoastguard = GridPosition(8, 3)

    /// Same first-frame reference as `Demo_Bomber` (row 12 col 2, shifted right of column centre).
    private static let handStartTile = GridPosition(12, 2)
    private static let handStartHorizontalOffsetTiles: CGFloat = 1.5

    /// Destination on opponent grass while scrolling.
    private static let grenadeHandTarget = GridPosition(3, 2)

    /// Scroll + hand motion to `grenadeHandTarget`.
    private static let scrollHandToTargetDuration: TimeInterval = 2

    /// Hold the opening frame (board + hand at home) before the scroll/hand motion begins.
    private static let freezeBeforeHandMotion: TimeInterval = 1

    /// Time from hand arrival at the target tile until the orange outline + haptic (total).
    private static let secondsAfterHandArrivalBeforeOutline: TimeInterval = 0.3

    /// Dwell with orange outline fully visible before the hit explosion pulse begins.
    private static let secondsAfterOrangeOutlineBeforeExplosion: TimeInterval = 1
    private static let orangeOutlineAnimationDuration: TimeInterval = 0.15

    /// Hide the hand after the hit explosion pulse has settled (matches `TileView` pulse timing).
    private static let delayHideHandAfterExplosionPulse: TimeInterval = 0.45

    /// Opacity animation when the hand is dismissed after the explosion.
    private static let handFadeOutDuration: TimeInterval = 0.35

    /// Pause after `ExplosionMiss` before the banner copy.
    private static let delayBeforeMissBanner: TimeInterval = 1

    @State private var didStart = false
    /// Hides the scroll content until the initial bottom pin scroll runs (avoids a top→bottom flash).
    @State private var isBoardVisible = false
    /// Circular close control appears only after the scripted beat finishes.
    @State private var showDemoFinished = false
    @State private var showHand = false
    @State private var handOpacity: CGFloat = 1
    @State private var handPosition = CGPoint.zero
    @State private var showGrenadeMissImpact = false
    @State private var grenadeImpactPulseToken: UInt32 = 0
    @State private var showGrenadeMissBanner = false
    @State private var showGrenadeTargetOutline = false

    var body: some View {
        GeometryReader { geo in
            let tileWidth = BoardGridMetrics.tileWidth(forContainerWidth: geo.size.width)
            let bottomInset = geo.safeAreaInsets.bottom
            let pullDown = max(0, bottomInset - Self.bottomCurveTapReserve)
            let tiles = makeTileMap(
                showGrenadeMissOnTarget: showGrenadeMissImpact,
                outlineGrenadeTarget: showGrenadeTargetOutline,
                grenadeImpactPulseToken: grenadeImpactPulseToken
            )

            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            ForEach(0..<BoardGridMetrics.rowCount, id: \.self) { row in
                                HStack(spacing: 0) {
                                    ForEach(0..<BoardGridMetrics.columnCount, id: \.self) { col in
                                        let pos = GridPosition(row, col)
                                        if let model = tiles[pos] {
                                            TileView(
                                                model: model,
                                                tileSize: tileWidth,
                                                onTap: {}
                                            )
                                            .equatable()
                                        }
                                    }
                                }
                                .frame(height: tileWidth)
                                .id("row-\(row)")

                                if row == 5 {
                                    Color.clear
                                        .frame(height: 0)
                                        .id(Zones.opponentDefenseSeamID)
                                }
                                if row == 7 {
                                    Color.clear
                                        .frame(height: 0)
                                        .id(Zones.playerDefenseSeamID)
                                }
                            }
                        }
                        .padding(.horizontal, BoardGridMetrics.horizontalPadding)
                        .padding(.bottom, -pullDown)
                    }
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .allowsHitTesting(false)
                    .opacity(isBoardVisible ? 1 : 0)
                    .onAppear {
                        guard !didStart else { return }
                        didStart = true
                        let bottomId = "row-\(BoardGridMetrics.rowCount - 1)"
                        DispatchQueue.main.async {
                            var t = Transaction()
                            t.disablesAnimations = true
                            withTransaction(t) {
                                proxy.scrollTo(bottomId, anchor: .bottom)
                            }
                            handPosition = Self.grenadeHandStartPosition(
                                viewportSize: geo.size,
                                pullDown: pullDown
                            )
                            handOpacity = 1
                            showHand = true
                            DispatchQueue.main.async {
                                isBoardVisible = true
                                Task {
                                    await runSequence(
                                        proxy: proxy,
                                        size: geo.size,
                                        pullDown: pullDown
                                    )
                                }
                            }
                        }
                    }
                }

                VStack(spacing: 0) {
                    if showGrenadeMissBanner {
                        Text("Missile eliminated!")
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .foregroundStyle(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

                if showHand {
                    Image("hand")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: Self.handSize, height: Self.handSize)
                        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
                        .opacity(handOpacity)
                        .position(handPosition)
                        .allowsHitTesting(false)
                }

            }
            .overlay(alignment: .topLeading) {
                DemoTopCloseButton(
                    isVisible: showDemoFinished,
                    onClose: onClose,
                    screenHeight: geo.size.height
                )
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    @MainActor
    private func runSequence(
        proxy: ScrollViewProxy,
        size: CGSize,
        pullDown: CGFloat
    ) async {
        showDemoFinished = false
        showGrenadeMissImpact = false
        grenadeImpactPulseToken = 0
        showGrenadeMissBanner = false
        showGrenadeTargetOutline = false
        handOpacity = 1

        let tw = BoardGridMetrics.tileWidth(forContainerWidth: size.width)

        let contentH = CGFloat(Zones.rowCount) * tw + pullDown
        let maxScroll = max(0, contentH - size.height)

        handPosition = Self.grenadeHandStartPosition(viewportSize: size, pullDown: pullDown)
        handOpacity = 1
        showHand = true

        let scrollTop = Self.clampedScrollOffsetCenteringRow(
            rowIndex: Self.grenadeHandTarget.row,
            tileWidth: tw,
            viewportHeight: size.height,
            maxScroll: maxScroll
        )

        let endPos = Self.handCentreAtTileLowerThird(
            row: Self.grenadeHandTarget.row,
            col: Self.grenadeHandTarget.col,
            viewportSize: size,
            scrollTopContentY: scrollTop
        )

        try? await Task.sleep(for: .seconds(Self.freezeBeforeHandMotion))

        withAnimation(.linear(duration: Self.scrollHandToTargetDuration)) {
            proxy.scrollTo("row-\(Self.grenadeHandTarget.row)", anchor: .center)
            handPosition = endPos
        }

        try? await Task.sleep(for: .seconds(Self.scrollHandToTargetDuration))

        try? await Task.sleep(for: .seconds(Self.secondsAfterHandArrivalBeforeOutline))

        Self.playOutlineTapHaptic()
        withAnimation(.easeOut(duration: Self.orangeOutlineAnimationDuration)) {
            showGrenadeTargetOutline = true
        }

        try? await Task.sleep(for: .seconds(Self.orangeOutlineAnimationDuration))
        try? await Task.sleep(for: .seconds(Self.secondsAfterOrangeOutlineBeforeExplosion))

        grenadeImpactPulseToken &+= 1
        var grenadeHitTransaction = Transaction()
        grenadeHitTransaction.disablesAnimations = true
        withTransaction(grenadeHitTransaction) {
            showGrenadeMissImpact = true
        }
        try? await Task.sleep(for: .seconds(Self.delayHideHandAfterExplosionPulse))
        withAnimation(.easeOut(duration: Self.handFadeOutDuration)) {
            handOpacity = 0
        }
        try? await Task.sleep(for: .seconds(Self.handFadeOutDuration))
        showHand = false
        handOpacity = 1

        let bannerDelayAfterFade = max(0, Self.delayBeforeMissBanner - Self.handFadeOutDuration)
        try? await Task.sleep(for: .seconds(bannerDelayAfterFade))

        withAnimation(.easeOut(duration: 0.2)) {
            showGrenadeMissBanner = true
        }

        showDemoFinished = true
    }

    /// Hand pose at row 12 / col 2 with scroll pinned to the bottom (first frame of the trailer).
    private static func grenadeHandStartPosition(viewportSize: CGSize, pullDown: CGFloat) -> CGPoint {
        let tw = BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width)
        let handAtStartTile = handCentreWithTopOfFrameAtTileLowerThird(
            row: handStartTile.row,
            col: handStartTile.col,
            viewportSize: viewportSize,
            pullDown: pullDown,
            scrollBottomPinned: true
        )
        return CGPoint(
            x: handAtStartTile.x + handStartHorizontalOffsetTiles * tw,
            y: handAtStartTile.y + initialHandExtraOffsetY
        )
    }

    /// Light tactile at scripted outline “press” (shared helper; avoids `.click` miniature sound).
    private static func playOutlineTapHaptic() {
        DemoScriptedOutlineHaptic.playAtOutlinePress()
    }

    /// Content offset **Y** with `rowIndex` centred vertically (clamped).
    private static func clampedScrollOffsetCenteringRow(
        rowIndex: Int,
        tileWidth tw: CGFloat,
        viewportHeight: CGFloat,
        maxScroll: CGFloat
    ) -> CGFloat {
        let rowMidY = CGFloat(rowIndex) * tw + tw / 2
        let raw = rowMidY - viewportHeight / 2
        return min(max(0, raw), maxScroll)
    }

    /// Same geometry as `Demo_Bomber` for the home-zone hand pose (scroll pinned to bottom of content).
    private static func handCentreWithTopOfFrameAtTileLowerThird(
        row: Int,
        col: Int,
        viewportSize: CGSize,
        pullDown: CGFloat,
        scrollBottomPinned: Bool
    ) -> CGPoint {
        let tw = BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width)
        let hp = BoardGridMetrics.horizontalPadding
        let cx = hp + CGFloat(col) * tw + tw / 2
        let yTopOfLowerThirdInContent = CGFloat(row) * tw + (2.0 / 3.0) * tw
        let contentH = CGFloat(Zones.rowCount) * tw + pullDown
        let offsetY = scrollBottomPinned ? max(0, contentH - viewportSize.height) : 0
        let yTopViewport = yTopOfLowerThirdInContent - offsetY
        let yCentre = yTopViewport + handSize / 2
        return CGPoint(x: cx, y: yCentre)
    }

    /// Lower-third hand anchor when content top is **`scrollTopContentY`** below the viewport top.
    private static func handCentreAtTileLowerThird(
        row: Int,
        col: Int,
        viewportSize: CGSize,
        scrollTopContentY O: CGFloat
    ) -> CGPoint {
        let tw = BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width)
        let hp = BoardGridMetrics.horizontalPadding
        let cx = hp + CGFloat(col) * tw + tw / 2
        let yTopOfLowerThirdInContent = CGFloat(row) * tw + (2.0 / 3.0) * tw
        let yTopViewport = yTopOfLowerThirdInContent - O
        let yCentre = yTopViewport + handSize / 2
        return CGPoint(x: cx, y: yCentre)
    }

    private func makeTileMap(
        showGrenadeMissOnTarget: Bool,
        outlineGrenadeTarget: Bool,
        grenadeImpactPulseToken: UInt32
    ) -> [GridPosition: TileRenderModel] {
        let marks: [GridPosition: Unit] = [
            Self.demoHQ: .headquarters,
            Self.demoMissile1: .missile,
            Self.demoMissile2: .missile,
            Self.demoBomber: .bomber,
            Self.demoCoastguard: .coastguard,
        ]

        var tiles: [GridPosition: TileRenderModel] = [:]
        for row in Zones.allRows {
            for col in Zones.allColumns {
                let pos = GridPosition(row, col)
                let missileOnGrenadeTarget = showGrenadeMissOnTarget
                let bg: TileBackground = {
                    if missileOnGrenadeTarget && pos == Self.demoMissile2 {
                        return Zones.isWater(pos.row) ? .water : .grass
                    }
                    if missileOnGrenadeTarget && pos == Self.grenadeHandTarget {
                        return .unit(.missile)
                    }
                    if let u = marks[pos] { return .unit(u) }
                    return Zones.isWater(pos.row) ? .water : .grass
                }()

                let dropOverlay: ExplosionKind? = {
                    if showGrenadeMissOnTarget && pos == Self.grenadeHandTarget { return .hit }
                    return nil
                }()

                let pulseToken: UInt32? = {
                    guard showGrenadeMissOnTarget, pos == Self.grenadeHandTarget else { return nil }
                    return grenadeImpactPulseToken
                }()

                let orangeTargetOutline =
                    outlineGrenadeTarget && pos == Self.grenadeHandTarget

                tiles[pos] = TileRenderModel(
                    position: pos,
                    background: bg,
                    bomberRotationDegrees: 0,
                    dim: .none,
                    offCoastguardFocusRow: false,
                    northStrikeOverlay: nil,
                    dropOverlay: dropOverlay,
                    dropOverlayScale: 1,
                    missileHitPulseToken: pulseToken,
                    waterWreck: nil,
                    wreckRotationDegrees: 0,
                    border: .plain,
                    isLastTurnHighlight: orangeTargetOutline,
                    isDisabled: false
                )
            }
        }
        return tiles
    }
}

#if DEBUG
#Preview {
    Demo_Grenade(onClose: {})
}
#endif
