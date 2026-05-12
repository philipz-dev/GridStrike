//  Demo_Bomber.swift

//  GridStrike Watch App

//

//  Scripted trailer: hand → bomber tile → scroll to enemy; tap → pauses → scroll so rows 5–6 sit on the bottom edge → bomber flies while board scrolls to top;

//  impacts (miss / miss / hit on the northernmost drop row) fire as the plane passes each row — dismiss with the top-left ✕ when the trailer ends.

//



import SwiftUI

import WatchKit



/// Parameters for the scripted bomber overlay (linear motion + scroll matched to `O0` → row 0 at top).

private struct BomberFlightSpec {

    let startTime: Date

    let duration: TimeInterval

    let cx: CGFloat

    let startY: CGFloat

    let endY: CGFloat

    let halfHeight: CGFloat

    /// Content Y coordinate pinned to the top of the viewport at flight start (`scrollTo` mid-board).

    let O0: CGFloat

}



struct Demo_Bomber: View {

    let onClose: () -> Void



    private static let bottomCurveTapReserve: CGFloat = 10

    private static let handSize: CGFloat = 48

    /// First-frame home-zone position: nudge the hand down so the asset reads right on cold start.

    private static let initialHandExtraOffsetY: CGFloat = 50

    private static let handFlyToHomeMissileDuration: TimeInterval = 0.75

    private static let scrollToTopDuration: TimeInterval = 2

    /// Dwell when the hand rests on the bomber tile or on the enemy tile before the scripted tap.

    private static let handPauseAtHoldPoint: TimeInterval = 0.5

    /// After the enemy destination “tap”, keep the hand visible on that tile before hiding it.

    private static let enemyDestinationHandDwellAfterTap: TimeInterval = 1

    /// Gap after the hand disappears before scrolling to the mid-board strike band.

    private static let delayBeforeBomberAfterHandHidden: TimeInterval = 0.5

    /// Scroll so rows 5–6 (water band) are in view before the bomber run.

    private static let scrollToMidBoardBeforeBomberDuration: TimeInterval = 1.1

    /// Vertical fly-by duration for `bomber_transparent` (bottom off-screen → top off-screen).

    private static let bomberFlightDuration: TimeInterval = 3.35

    /// Bomber sprite width/height as a multiple of tile width (matches scroll geometry).

    private static let bomberFlightSpriteTileFactor: CGFloat = 1.22

    /// Non-HQ-hit cells: appears at **200%** on the crossing beat, then eases to **100%** (no pre-delay). HQ hit uses `TileView` pulse like `Demo_Grenade`.
    private static let hitExplosionShrinkDuration: TimeInterval = 0.22

    // MARK: - Demo layout (row, col)



    private static let demoHQ = GridPosition(10, 3)

    private static let demoMissile1 = GridPosition(11, 0)

    private static let demoMissile2 = GridPosition(9, 1)

    private static let demoBomber = GridPosition(12, 2)

    private static let demoCoastguard = GridPosition(8, 3)

    /// Enemy grass anchor for the scripted bomber tap (column strike walks north from here).

    private static let enemyBomberTarget = GridPosition(3, 1)

    /// Final bomber-drop hit cell: HQ tile art + same pulse path as `Demo_Grenade` (`HeadquarterTile` underlay).

    private static let bomberDemoHqHitTile = GridPosition(1, 1)

    /// Settle time for that pulse (matches `TileView` hit animation).

    private static let bomberHqHitPulseSettleDuration: TimeInterval = 0.45

    /// Vertical / reference column for first hand pose (row 12, col 2 — bomber). Hand image is

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

    @State private var missileImpactOverlays: [GridPosition: ExplosionKind] = [:]

    @State private var missileImpactOverlayScales: [GridPosition: CGFloat] = [:]

    @State private var bomberHqHitPulseToken: UInt32 = 0

    @State private var showHitBanner = false

    /// When non-nil, timeline-driven bomber path; opacity hides only after the sprite clears the watch top.

    @State private var bomberFlightSpec: BomberFlightSpec?



    var body: some View {

        GeometryReader { geo in

            let tileWidth = BoardGridMetrics.tileWidth(forContainerWidth: geo.size.width)

            let bomberSprite = tileWidth * Self.bomberFlightSpriteTileFactor

            let bottomInset = geo.safeAreaInsets.bottom

            let pullDown = max(0, bottomInset - Self.bottomCurveTapReserve)

            let tiles = makeTileMap(

                highlightPlayerMissile: highlightPlayerMissile,

                highlightEnemyAnchor: highlightEnemyAnchor,

                missileImpactOverlays: missileImpactOverlays,

                missileImpactOverlayScales: missileImpactOverlayScales,

                bomberHqHitPulseToken: bomberHqHitPulseToken

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



                // Same placement + typography as `InstructionBanner` / “Start attack!”

                VStack(spacing: 0) {

                    if showHitBanner {

                        Text("HQ eliminated!")

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



                if let flight = bomberFlightSpec {

                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in

                        let elapsed = timeline.date.timeIntervalSince(flight.startTime)

                        let p = min(1.0, elapsed / flight.duration)

                        let y = flight.startY + (flight.endY - flight.startY) * CGFloat(p)

                        // Stay visible until the sprite’s bottom edge clears the viewport top (y = 0). Don’t tie this to scrolling row 0 or it pops off early.
                        let bottomOfPlane = y + flight.halfHeight
                        let showPlane = bottomOfPlane > 0



                        Image("bomber_transparent")

                            .resizable()

                            .interpolation(.high)

                            .scaledToFit()

                            .frame(width: bomberSprite, height: bomberSprite)

                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

                            .position(x: flight.cx, y: y)

                            .opacity(showPlane ? 1 : 0)

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

        missileImpactOverlays = [:]

        missileImpactOverlayScales = [:]

        bomberHqHitPulseToken = 0

        // Start: same row / vertical alignment as row 12 col 2, but hand sits 1.5 tiles right of col 2 centre.

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



        let handOnBomberTile = Self.handCentreWithTopOfFrameAtTileLowerThird(

            row: Self.demoBomber.row,

            col: Self.demoBomber.col,

            viewportSize: size,

            pullDown: pullDown,

            scrollBottomPinned: true

        )

        let homeTapPos = CGPoint(

            x: handOnBomberTile.x,

            y: handOnBomberTile.y + Self.initialHandExtraOffsetY

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

        // Keep orange on the bomber tile through the upcoming scroll (don’t clear yet).



        // Final hand position (enemy zone, scroll pinned to top) — lower-third alignment on bomb target tile.

        let handAtAnchor = Self.handCentreWithTopOfFrameAtTileLowerThird(

            row: Self.enemyBomberTarget.row,

            col: Self.enemyBomberTarget.col,

            viewportSize: size,

            pullDown: pullDown,

            scrollBottomPinned: false

        )



        // Scroll and hand move together: straight-line motion in screen space over the same duration.

        withAnimation(.linear(duration: Self.scrollToTopDuration)) {

            proxy.scrollTo("row-0", anchor: .top)

            handPosition = handAtAnchor

        }

        try? await Task.sleep(for: .seconds(Self.scrollToTopDuration))



        // Pause with hand on enemy tile before the scripted tap (outline + impact).

        try? await Task.sleep(for: .seconds(Self.handPauseAtHoldPoint))



        highlightEnemyAnchor = true

        Self.playOutlineTapHaptic()



        try? await Task.sleep(for: .seconds(Self.enemyDestinationHandDwellAfterTap))



        // Hide finger; keep orange on home bomber and enemy target through the fly-through and banner.

        showHand = false



        try? await Task.sleep(for: .seconds(Self.delayBeforeBomberAfterHandHidden))



        // Pin row 6’s bottom to the viewport bottom so rows 5 and 6 are the lowest visible rows.

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardBeforeBomberDuration)) {

            proxy.scrollTo("row-6", anchor: .bottom)

        }

        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardBeforeBomberDuration))



        let drops = Rules.bombingPositions(target: Self.enemyBomberTarget, attacker: .player)

        let kinds: [ExplosionKind] = [.miss, .miss, .hit]



        let hp = BoardGridMetrics.horizontalPadding

        let col = Self.enemyBomberTarget.col

        let cx = hp + CGFloat(col) * tw + tw / 2

        let sprite = tw * Self.bomberFlightSpriteTileFactor

        let half = sprite / 2

        let startY = size.height + half + 28

        let endY = -half - 28

        let T = Self.bomberFlightDuration



        let contentH = CGFloat(Zones.rowCount) * tw + pullDown

        let maxScroll = max(0, contentH - size.height)

        /// Content Y at viewport top after `scrollTo("row-6", anchor: .bottom)` (row 6 flush to bottom edge).

        let O0 = Self.clampedScrollOffsetPinningBottomOfRow(

            rowIndex: 6,

            tileWidth: tw,

            viewportHeight: size.height,

            maxScroll: maxScroll

        )

        /// End state: row 0 aligned to top (`scrollTo("row-0", anchor: .top)`).

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



        bomberFlightSpec = BomberFlightSpec(

            startTime: Date(),

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



        var previousTau: TimeInterval = 0

        /// After the delayed hit finishes, shorten the **next** crossing wait by this (delay + scale animations).
        var shortenNextCrossingDeltaBy: TimeInterval = 0

        for index in drops.indices {

            let pos = drops[index]

            let kind = index < kinds.count ? kinds[index] : .miss

            let targetTau = tauWhenCrossingRow(pos.row)

            let delta = max(0, targetTau - previousTau)

            previousTau = targetTau

            let sleepCrossing = max(0, delta - shortenNextCrossingDeltaBy)

            shortenNextCrossingDeltaBy = 0

            if sleepCrossing > 0 {

                try? await Task.sleep(for: .seconds(sleepCrossing))

            }

            var overlays = missileImpactOverlays

            overlays[pos] = kind

            if kind == .hit {

                if pos == Self.bomberDemoHqHitTile {

                    bomberHqHitPulseToken &+= 1

                    var hqHitTx = Transaction()

                    hqHitTx.disablesAnimations = true

                    withTransaction(hqHitTx) {

                        var scales = missileImpactOverlayScales

                        scales[pos] = 1

                        missileImpactOverlayScales = scales

                        missileImpactOverlays = overlays

                    }

                    await Task.yield()

                    try? await Task.sleep(for: .seconds(Self.bomberHqHitPulseSettleDuration))

                    shortenNextCrossingDeltaBy = Self.bomberHqHitPulseSettleDuration

                } else {

                    var scales = missileImpactOverlayScales

                    scales[pos] = 2

                    missileImpactOverlayScales = scales

                    missileImpactOverlays = overlays

                    await Task.yield()

                    withAnimation(.easeOut(duration: Self.hitExplosionShrinkDuration)) {

                        var s = missileImpactOverlayScales

                        s[pos] = 1

                        missileImpactOverlayScales = s

                    }

                    try? await Task.sleep(for: .seconds(Self.hitExplosionShrinkDuration))

                    shortenNextCrossingDeltaBy = Self.hitExplosionShrinkDuration

                }

            } else {

                var scales = missileImpactOverlayScales

                scales[pos] = 1

                withAnimation(.easeOut(duration: 0.2)) {

                    missileImpactOverlays = overlays

                    missileImpactOverlayScales = scales

                }

            }

        }



        let remaining = max(0, T - previousTau)

        if remaining > 0 {

            try? await Task.sleep(for: .seconds(remaining))

        }

        bomberFlightSpec = nil

        withAnimation(.easeOut(duration: 0.2)) {

            showHitBanner = true

        }

        showDemoFinished = true

    }



    /// Light tactile “tap” when orange selection outlines appear (watch speaker silent).

    private static func playOutlineTapHaptic() {

        WKInterfaceDevice.current().play(.click)

    }



    /// Scroll offset when the **bottom** of `rowIndex` aligns with the viewport bottom (`scrollTo(..., anchor: .bottom)`).

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



    // MARK: - Geometry (matches `BoardView` scroll padding)



    /// Centres the hand asset so the **top edge** of its fixed `handSize` square sits exactly

    /// on the **top edge of the tile's lower third** (the horizontal line at ⅔ down the cell).

    /// The upper opaque finger art in `hand.png` then lands in that bottom band. Horizontal:

    /// column centre.

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

        missileImpactOverlays: [GridPosition: ExplosionKind],

        missileImpactOverlayScales: [GridPosition: CGFloat],

        bomberHqHitPulseToken: UInt32

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

                let hqHitShowing = missileImpactOverlays[Self.bomberDemoHqHitTile] == .hit



                let bg: TileBackground = {

                    if hqHitShowing && pos == Self.demoHQ {

                        return Zones.isWater(pos.row) ? .water : .grass

                    }

                    if hqHitShowing && pos == Self.bomberDemoHqHitTile {

                        return .unit(.headquarters)

                    }

                    if let u = marks[pos] { return .unit(u) }

                    return Zones.isWater(pos.row) ? .water : .grass

                }()



                let highlight =

                    (highlightPlayerMissile && pos == Self.demoBomber)

                    || (highlightEnemyAnchor && pos == Self.enemyBomberTarget)



                let pulseToken: UInt32? = {

                    guard missileImpactOverlays[pos] == .hit else { return nil }

                    guard pos == Self.bomberDemoHqHitTile else { return nil }

                    return bomberHqHitPulseToken

                }()



                let dropOverlayScale: CGFloat = {

                    if pos == Self.bomberDemoHqHitTile, missileImpactOverlays[pos] == .hit {

                        return 1

                    }

                    return missileImpactOverlayScales[pos] ?? 1

                }()



                tiles[pos] = TileRenderModel(

                    position: pos,

                    background: bg,

                    bomberRotationDegrees: 0,

                    dim: .none,

                    offCoastguardFocusRow: false,

                    northStrikeOverlay: nil,

                    dropOverlay: missileImpactOverlays[pos],

                    dropOverlayScale: dropOverlayScale,

                    missileHitPulseToken: pulseToken,

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

    Demo_Bomber(onClose: {})

}

#endif
