//
//  Demo_Coastguard.swift
//  GridStrike Watch App
//
//  Coastguard intercept trailer: fly-up with scroll pinned to row 6; on intercept, explosion overlay on row 6 scales up
//  then fades; coastguard fades in on row 5 (`Missile intercepted by coastguard!`).
//

import SwiftUI
import WatchKit

/// Parameters for the scripted missile overlay (linear screen motion; scroll stays pinned).
private struct MissileFlightSpec {
    let startTime: Date
    let duration: TimeInterval
    let cx: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let halfHeight: CGFloat
}

struct Demo_Coastguard: View {
    let onClose: () -> Void

    private static let bottomCurveTapReserve: CGFloat = 10
    private static let handSize: CGFloat = 48
    /// First-frame home-zone position: nudge the hand down so the asset reads right on cold start.
    private static let initialHandExtraOffsetY: CGFloat = 50
    private static let scrollToTopDuration: TimeInterval = 2
    /// Dwell when the hand rests on the missile tile or on the enemy tile before the scripted tap.
    private static let handPauseAtHoldPoint: TimeInterval = 0.5
    /// After the enemy destination “tap”, keep the hand visible on that tile before hiding it.
    private static let enemyDestinationHandDwellAfterTap: TimeInterval = 1
    /// Gap after the hand disappears before scrolling to the mid-board strike band.
    private static let delayBeforeMissileAfterHandHidden: TimeInterval = 0.5
    /// Scroll so rows 5–6 (water band) are in view before the missile run.
    private static let scrollToMidBoardBeforeMissileDuration: TimeInterval = 1.1
    /// Vertical fly-by duration for `missiletransparent` (bottom off-screen → top off-screen).
    private static let missileFlightDuration: TimeInterval = 3.35
    /// Missile sprite width/height as a multiple of tile width (matches scroll geometry).
    private static let missileFlightSpriteTileFactor: CGFloat = 1.22
    /// Hand flies to `demoMissile2` (matches prior missile demo pacing).
    private static let handFlyToHomeMissileDuration: TimeInterval = 1.75
    /// Intercept explosion: scale 25% → 200%, then fade out.
    private static let interceptExplosionGrowDuration: TimeInterval = 0.14 * 1.2
    private static let interceptExplosionFadeDuration: TimeInterval = 0.24
    /// Fade-in for the coastguard overlay on row 5 (half the prior duration = 2× speed).
    private static let interceptCoastguardFadeDuration: TimeInterval = (2.4 * 1.2) / 2
    /// Pause after the intercept beat before the top banner (`Missile intercepted by coastguard!`).
    private static let delayBeforeInterceptBanner: TimeInterval = 1

    // MARK: - Demo layout (row, col)

    private static let demoHQ = GridPosition(10, 3)
    private static let demoMissile1 = GridPosition(11, 0)
    private static let demoMissile2 = GridPosition(9, 1)
    private static let demoBomber = GridPosition(12, 2)
    private static let demoCoastguard = GridPosition(8, 3)
    /// Enemy grass anchor for the scripted missile tap (X-pattern centre).
    private static let enemyMissileAnchor = GridPosition(2, 3)
    /// Flying sprite is removed when its centre crosses this row (one row south of row 5 water band).
    private static let missileDismissRow = 6
    /// Vertical / reference column for first hand pose (row 12, col 2). Hand image is
    /// shifted **`handStartHorizontalOffsetTiles`** to the right of that column centre.
    private static let handStartTile = GridPosition(12, 2)
    private static let handStartHorizontalOffsetTiles: CGFloat = 1.5

    @State private var didStart = false
    /// Hides the scroll content until the initial bottom pin scroll runs (avoids a top→bottom flash).
    @State private var isBoardVisible = false
    /// Circular close control appears only after the scripted beat finishes.
    @State private var showDemoFinished = false
    @State private var showHand = false
    @State private var handPosition = CGPoint.zero
    @State private var highlightPlayerMissile = false
    @State private var highlightEnemyAnchor = false
    @State private var showHitBanner = false
    /// When non-nil, timeline-driven `missiletransparent` overlay (cleared when centre crosses row 6).
    @State private var missileFlightSpec: MissileFlightSpec?
    @State private var showInterceptExplosionOverlay = false
    @State private var interceptExplosionScale: CGFloat = 0.25
    @State private var interceptExplosionOpacity: CGFloat = 1
    @State private var showInterceptCoastguardOverlay = false
    @State private var interceptCoastguardOpacity: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let tileWidth = BoardGridMetrics.tileWidth(forContainerWidth: geo.size.width)
            let missileSprite = tileWidth * Self.missileFlightSpriteTileFactor
            let bottomInset = geo.safeAreaInsets.bottom
            let pullDown = max(0, bottomInset - Self.bottomCurveTapReserve)
            let contentH = CGFloat(Zones.rowCount) * tileWidth + pullDown
            let maxScroll = max(0, contentH - geo.size.height)
            let scrollTopPinnedRow6 = Self.clampedScrollOffsetPinningBottomOfRow(
                rowIndex: 6,
                tileWidth: tileWidth,
                viewportHeight: geo.size.height,
                maxScroll: maxScroll
            )
            let tiles = makeTileMap(
                highlightPlayerMissile: highlightPlayerMissile,
                highlightEnemyAnchor: highlightEnemyAnchor
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
                    if showHitBanner {
                        Text("Missile intercepted by coastguard!")
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
                        .position(handPosition)
                        .allowsHitTesting(false)
                }

                if showInterceptCoastguardOverlay {
                    let hp = BoardGridMetrics.horizontalPadding
                    let cgCentre = Self.tileCentreScreen(
                        row: 5,
                        col: Self.enemyMissileAnchor.col,
                        tw: tileWidth,
                        hp: hp,
                        scrollTopContentY: scrollTopPinnedRow6
                    )
                    Assets.coastguard
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: tileWidth * 0.92, height: tileWidth * 0.92)
                        .position(cgCentre)
                        .opacity(interceptCoastguardOpacity)
                        .allowsHitTesting(false)
                }

                if showInterceptExplosionOverlay {
                    let hp = BoardGridMetrics.horizontalPadding
                    let boomCentre = Self.tileCentreScreen(
                        row: Self.missileDismissRow,
                        col: Self.enemyMissileAnchor.col,
                        tw: tileWidth,
                        hp: hp,
                        scrollTopContentY: scrollTopPinnedRow6
                    )
                    Assets.explosionImage(for: .hit)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: tileWidth * 0.92, height: tileWidth * 0.92)
                        .scaleEffect(interceptExplosionScale)
                        .opacity(interceptExplosionOpacity)
                        .position(boomCentre)
                        .allowsHitTesting(false)
                }

                if let flight = missileFlightSpec {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                        let elapsed = timeline.date.timeIntervalSince(flight.startTime)
                        let p = min(1.0, elapsed / flight.duration)
                        let y = flight.startY + (flight.endY - flight.startY) * CGFloat(p)
                        // Hide once the bottom edge clears **half a sprite height** below the viewport top (not flush at y = 0).
                        let bottomOfMissile = y + flight.halfHeight
                        let showMissile = bottomOfMissile > flight.halfHeight

                        Image("missiletransparent")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: missileSprite, height: missileSprite)
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                            .position(x: flight.cx, y: y)
                            .opacity(showMissile ? 1 : 0)
                            .allowsHitTesting(false)
                    }
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

    // MARK: - Scripted timeline

    @MainActor
    private func runSequence(
        proxy: ScrollViewProxy,
        size: CGSize,
        pullDown: CGFloat
    ) async {
        showDemoFinished = false
        try? await Task.sleep(for: .seconds(1))

        highlightPlayerMissile = false
        highlightEnemyAnchor = false

        showHitBanner = false
        missileFlightSpec = nil
        showInterceptExplosionOverlay = false
        interceptExplosionScale = 0.25
        interceptExplosionOpacity = 1
        showInterceptCoastguardOverlay = false
        interceptCoastguardOpacity = 0

        let tw = BoardGridMetrics.tileWidth(forContainerWidth: size.width)
        let handAtStartTile = Self.handCentreWithTopOfFrameAtTileLowerThird(
            row: Self.handStartTile.row,
            col: Self.handStartTile.col,
            viewportSize: size,
            pullDown: pullDown,
            scrollBottomPinned: true
        )
        let startPos = CGPoint(
            x: handAtStartTile.x + Self.handStartHorizontalOffsetTiles * tw,
            y: handAtStartTile.y + Self.initialHandExtraOffsetY
        )

        let handOnMissile = Self.handCentreWithTopOfFrameAtTileLowerThird(
            row: Self.demoMissile2.row,
            col: Self.demoMissile2.col,
            viewportSize: size,
            pullDown: pullDown,
            scrollBottomPinned: true
        )
        let homeTapPos = CGPoint(
            x: handOnMissile.x,
            y: handOnMissile.y + Self.initialHandExtraOffsetY
        )

        showHand = true
        handPosition = startPos

        withAnimation(.easeInOut(duration: Self.handFlyToHomeMissileDuration)) {
            handPosition = homeTapPos
        }
        try? await Task.sleep(for: .seconds(Self.handFlyToHomeMissileDuration))

        try? await Task.sleep(for: .seconds(Self.handPauseAtHoldPoint))
        Self.playOutlineTapHaptic()
        highlightPlayerMissile = true

        try? await Task.sleep(for: .seconds(Self.handPauseAtHoldPoint))

        let handAtAnchor = Self.handCentreWithTopOfFrameAtTileLowerThird(
            row: Self.enemyMissileAnchor.row,
            col: Self.enemyMissileAnchor.col,
            viewportSize: size,
            pullDown: pullDown,
            scrollBottomPinned: false
        )

        withAnimation(.linear(duration: Self.scrollToTopDuration)) {
            proxy.scrollTo("row-0", anchor: .top)
            handPosition = handAtAnchor
        }
        try? await Task.sleep(for: .seconds(Self.scrollToTopDuration))

        try? await Task.sleep(for: .seconds(Self.handPauseAtHoldPoint))

        Self.playOutlineTapHaptic()
        highlightEnemyAnchor = true

        try? await Task.sleep(for: .seconds(Self.enemyDestinationHandDwellAfterTap))

        showHand = false

        try? await Task.sleep(for: .seconds(Self.delayBeforeMissileAfterHandHidden))

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardBeforeMissileDuration)) {
            proxy.scrollTo("row-6", anchor: .bottom)
        }
        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardBeforeMissileDuration))

        let hp = BoardGridMetrics.horizontalPadding
        let col = Self.enemyMissileAnchor.col
        let cx = hp + CGFloat(col) * tw + tw / 2
        let sprite = tw * Self.missileFlightSpriteTileFactor
        let half = sprite / 2
        let startY = size.height + half + 28
        let endY = -half - 28
        let T = Self.missileFlightDuration

        let contentH = CGFloat(Zones.rowCount) * tw + pullDown
        let maxScroll = max(0, contentH - size.height)
        let O0 = Self.clampedScrollOffsetPinningBottomOfRow(
            rowIndex: 6,
            tileWidth: tw,
            viewportHeight: size.height,
            maxScroll: maxScroll
        )
        // Fixed scroll at row-6 bottom: screen Y of a board content midline is `contentY - O0`.
        func tauWhenMissileCentreCrossesContentYMid(_ contentYMid: CGFloat) -> TimeInterval {
            let targetScreenY = contentYMid - O0
            let den = endY - startY
            guard abs(den) > 1 else { return 0 }
            let u = (targetScreenY - startY) / den
            return max(0, min(T, T * TimeInterval(u)))
        }

        let flightStart = Date()
        missileFlightSpec = MissileFlightSpec(
            startTime: flightStart,
            duration: T,
            cx: cx,
            startY: startY,
            endY: endY,
            halfHeight: half
        )

        // Dismiss fly sprite when centre crosses row 6 mid (one row below former row-5 cue).
        let yDismissMid = CGFloat(Self.missileDismissRow) * tw + tw / 2
        var tauDismiss = tauWhenMissileCentreCrossesContentYMid(yDismissMid)
        tauDismiss = max(0, min(T, tauDismiss))

        let elapsedBeforeWait = Date().timeIntervalSince(flightStart)
        let waitDismiss = max(0, tauDismiss - elapsedBeforeWait)
        if waitDismiss > 0 {
            try? await Task.sleep(for: .seconds(waitDismiss))
        }

        missileFlightSpec = nil

        showInterceptExplosionOverlay = true
        interceptExplosionScale = 0.25
        interceptExplosionOpacity = 1

        showInterceptCoastguardOverlay = true
        interceptCoastguardOpacity = 0
        withAnimation(.easeIn(duration: Self.interceptCoastguardFadeDuration)) {
            interceptCoastguardOpacity = 1
        }

        await Task.yield()
        withAnimation(.easeOut(duration: Self.interceptExplosionGrowDuration)) {
            interceptExplosionScale = 2.0
        }
        try? await Task.sleep(for: .seconds(Self.interceptExplosionGrowDuration))

        withAnimation(.easeOut(duration: Self.interceptExplosionFadeDuration)) {
            interceptExplosionOpacity = 0
        }
        try? await Task.sleep(for: .seconds(Self.interceptExplosionFadeDuration))
        showInterceptExplosionOverlay = false
        interceptExplosionScale = 0.25
        interceptExplosionOpacity = 1

        let totalElapsed = Date().timeIntervalSince(flightStart)
        let remaining = max(0, T - totalElapsed)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
        try? await Task.sleep(for: .seconds(Self.delayBeforeInterceptBanner))
        withAnimation(.easeOut(duration: 0.2)) {
            showHitBanner = true
        }

        showDemoFinished = true
    }

    private static func playOutlineTapHaptic() {
        DemoScriptedOutlineHaptic.playAtOutlinePress()
    }

    /// Screen-space centre of a tile when content offset **O** is pinned at the viewport top.
    private static func tileCentreScreen(
        row: Int,
        col: Int,
        tw: CGFloat,
        hp: CGFloat,
        scrollTopContentY O: CGFloat
    ) -> CGPoint {
        let cx = hp + CGFloat(col) * tw + tw / 2
        let cy = CGFloat(row) * tw + tw / 2 - O
        return CGPoint(x: cx, y: cy)
    }

    private static func clampedScrollOffsetPinningBottomOfRow(
        rowIndex: Int,
        tileWidth tw: CGFloat,
        viewportHeight: CGFloat,
        maxScroll: CGFloat
    ) -> CGFloat {
        let yBottom = CGFloat(rowIndex + 1) * tw
        let raw = yBottom - viewportHeight
        return min(max(0, raw), maxScroll)
    }

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

    // MARK: - Tile map

    private func makeTileMap(
        highlightPlayerMissile: Bool,
        highlightEnemyAnchor: Bool
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
                let bg: TileBackground = {
                    if let u = marks[pos] { return .unit(u) }
                    return Zones.isWater(pos.row) ? .water : .grass
                }()

                let highlight =
                    (highlightPlayerMissile && pos == Self.demoMissile2)
                    || (highlightEnemyAnchor && pos == Self.enemyMissileAnchor)

                tiles[pos] = TileRenderModel(
                    position: pos,
                    background: bg,
                    bomberRotationDegrees: 0,
                    dim: .none,
                    offCoastguardFocusRow: false,
                    northStrikeOverlay: nil,
                    dropOverlay: nil,
                    dropOverlayScale: 1,
                    missileHitPulseToken: nil,
                    waterWreck: nil,
                    wreckRotationDegrees: 0,
                    border: .plain,
                    isLastTurnHighlight: highlight,
                    isDisabled: false
                )
            }
        }
        return tiles
    }
}

#if DEBUG
#Preview {
    Demo_Coastguard(onClose: {})
}
#endif
