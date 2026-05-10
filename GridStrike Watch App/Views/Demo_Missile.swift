//
//  Demo_Missile.swift
//  GridStrike Watch App
//
//  Scripted trailer: hand → home missile → enemy anchor tap; scroll pins row 6; `missiletransparent`
//  flies up the anchor column while the board scrolls to top; when the sprite reaches row 2 all salvo
//  impacts appear at once and the flying sprite is removed — tap anywhere to dismiss.
//

import SwiftUI
import WatchKit

/// Parameters for the scripted missile overlay (linear motion + scroll matched to `O0` → row 0 at top).
private struct MissileFlightSpec {
    let startTime: Date
    let duration: TimeInterval
    let cx: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let halfHeight: CGFloat
    /// Content Y coordinate pinned to the top of the viewport at flight start (`scrollTo` mid-board).
    let O0: CGFloat
}

struct Demo_Missile: View {
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

    // MARK: - Demo layout (row, col)

    private static let demoHQ = GridPosition(10, 3)
    private static let demoMissile1 = GridPosition(11, 0)
    private static let demoMissile2 = GridPosition(9, 1)
    private static let demoBomber = GridPosition(12, 2)
    private static let demoCoastguard = GridPosition(8, 3)
    /// Enemy grass anchor for the scripted missile tap (X-pattern centre).
    private static let enemyMissileAnchor = GridPosition(2, 3)
    /// Vertical / reference column for first hand pose (row 12, col 2). Hand image is
    /// shifted **`handStartHorizontalOffsetTiles`** to the right of that column centre.
    private static let handStartTile = GridPosition(12, 2)
    private static let handStartHorizontalOffsetTiles: CGFloat = 1.5

    @State private var didStart = false
    @State private var showHand = false
    @State private var handPosition = CGPoint.zero
    @State private var highlightPlayerMissile = false
    @State private var highlightEnemyAnchor = false
    @State private var missileImpactOverlays: [GridPosition: ExplosionKind] = [:]
    @State private var showHitBanner = false
    /// When non-nil, timeline-driven `missiletransparent` overlay (cleared when impacts flash at row 2).
    @State private var missileFlightSpec: MissileFlightSpec?

    var body: some View {
        GeometryReader { geo in
            let tileWidth = BoardGridMetrics.tileWidth(forContainerWidth: geo.size.width)
            let missileSprite = tileWidth * Self.missileFlightSpriteTileFactor
            let bottomInset = geo.safeAreaInsets.bottom
            let pullDown = max(0, bottomInset - Self.bottomCurveTapReserve)
            let tiles = makeTileMap(
                highlightPlayerMissile: highlightPlayerMissile,
                highlightEnemyAnchor: highlightEnemyAnchor,
                missileImpactOverlays: missileImpactOverlays
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
                    .onAppear {
                        guard !didStart else { return }
                        didStart = true
                        let bottomId = "row-\(BoardGridMetrics.rowCount - 1)"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            proxy.scrollTo(bottomId, anchor: .bottom)
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

                VStack(spacing: 0) {
                    if showHitBanner {
                        Text("Hostile missile hit!")
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

                if let flight = missileFlightSpec {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                        let elapsed = timeline.date.timeIntervalSince(flight.startTime)
                        let p = min(1.0, elapsed / flight.duration)
                        let y = flight.startY + (flight.endY - flight.startY) * CGFloat(p)
                        let bottomOfMissile = y + flight.halfHeight
                        let showMissile = bottomOfMissile > 0

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

                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture { onClose() }
                    .accessibilityLabel("Dismiss missile demo")
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
        try? await Task.sleep(for: .seconds(1))

        missileImpactOverlays = [:]
        showHitBanner = false
        missileFlightSpec = nil

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
        highlightPlayerMissile = true
        Self.playOutlineTapHaptic()

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

        highlightPlayerMissile = false
        highlightEnemyAnchor = true
        Self.playOutlineTapHaptic()

        try? await Task.sleep(for: .seconds(Self.enemyDestinationHandDwellAfterTap))

        showHand = false

        try? await Task.sleep(for: .seconds(Self.delayBeforeMissileAfterHandHidden))

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardBeforeMissileDuration)) {
            proxy.scrollTo("row-6", anchor: .bottom)
        }
        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardBeforeMissileDuration))

        let salvo = Rules.missilePositions(anchor: Self.enemyMissileAnchor, attacker: .player)
        let nw = GridPosition(Self.enemyMissileAnchor.row - 1, Self.enemyMissileAnchor.col - 1)
        guard !salvo.isEmpty else {
            highlightEnemyAnchor = false
            return
        }

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
        let O1: CGFloat = 0

        func tauWhenCrossingRow(_ row: Int) -> TimeInterval {
            let yTileMid = CGFloat(row) * tw + tw / 2
            let num = yTileMid - O0 - startY
            let den = (endY - startY) + (O1 - O0)
            guard abs(den) > 0.5 else {
                return T * TimeInterval((yTileMid - startY) / (endY - startY))
            }
            let p = num / den
            return T * TimeInterval(max(0, min(1, p)))
        }

        let flightStart = Date()
        missileFlightSpec = MissileFlightSpec(
            startTime: flightStart,
            duration: T,
            cx: cx,
            startY: startY,
            endY: endY,
            halfHeight: half,
            O0: O0
        )

        withAnimation(.linear(duration: T)) {
            proxy.scrollTo("row-0", anchor: .top)
        }

        // Anchor row (2): show full salvo and dismiss `missiletransparent` when the sprite crosses here.
        let triggerRow = Self.enemyMissileAnchor.row
        var tauAtRow2 = tauWhenCrossingRow(triggerRow)
        tauAtRow2 = max(0, min(T, tauAtRow2))

        let elapsedBeforeWait = Date().timeIntervalSince(flightStart)
        let waitRow2 = max(0, tauAtRow2 - elapsedBeforeWait)
        if waitRow2 > 0 {
            try? await Task.sleep(for: .seconds(waitRow2))
        }

        var overlays: [GridPosition: ExplosionKind] = [:]
        for pos in salvo {
            overlays[pos] = (pos == nw) ? .hit : .miss
        }

        missileFlightSpec = nil
        withAnimation(.easeOut(duration: 0.2)) {
            missileImpactOverlays = overlays
        }

        let totalElapsed = Date().timeIntervalSince(flightStart)
        let remaining = max(0, T - totalElapsed)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
        highlightEnemyAnchor = false
        withAnimation(.easeOut(duration: 0.2)) {
            showHitBanner = true
        }
    }

    private static func playOutlineTapHaptic() {
        WKInterfaceDevice.current().play(.click)
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
        highlightEnemyAnchor: Bool,
        missileImpactOverlays: [GridPosition: ExplosionKind]
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
                    dropOverlay: missileImpactOverlays[pos],
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
    Demo_Missile(onClose: {})
}
#endif
