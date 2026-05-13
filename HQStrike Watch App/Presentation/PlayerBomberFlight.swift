//
//  PlayerBomberFlight.swift
//  HQStrike Watch App
//
//  Same motion model as `Demo_Bomber`: mid-board scroll pin, linear scroll to row 0 while
//  `bomber_transparent` crosses the viewport, with impact times from `tauWhenCrossingRow`.
//

import SwiftUI

struct LiveBomberFlightSpec: Equatable {
    let startTime: Date
    let duration: TimeInterval
    let cx: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let halfHeight: CGFloat
    /// Content Y at viewport top at flight start (after pinning row 6 bottom).
    let O0: CGFloat
    /// Opponent missile: sprite enters from the north and flies downward.
    let missileFliesDownward: Bool
    /// Extra rotation for the missile asset (opponent uses 180°).
    let spriteRotationDegrees: Double

    init(
        startTime: Date,
        duration: TimeInterval,
        cx: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        halfHeight: CGFloat,
        O0: CGFloat,
        missileFliesDownward: Bool = false,
        spriteRotationDegrees: Double = 0
    ) {
        self.startTime = startTime
        self.duration = duration
        self.cx = cx
        self.startY = startY
        self.endY = endY
        self.halfHeight = halfHeight
        self.O0 = O0
        self.missileFliesDownward = missileFliesDownward
        self.spriteRotationDegrees = spriteRotationDegrees
    }
}

enum LivePlayerBomberFlight {
    static let scrollToMidBoardDuration: TimeInterval = 1.1
    static let flightDuration: TimeInterval = 3.35
    static let spriteTileFactor: CGFloat = 1.22

    /// Scroll offset when the bottom of `rowIndex` aligns with the viewport bottom.
    static func clampedScrollOffsetPinningBottomOfRow(
        rowIndex: Int,
        tileWidth tw: CGFloat,
        viewportHeight: CGFloat,
        maxScroll: CGFloat
    ) -> CGFloat {
        let yBottom = CGFloat(rowIndex + 1) * tw
        let raw = yBottom - viewportHeight
        return min(max(0, raw), maxScroll)
    }

    /// Scroll offset when the top edge of `rowIndex` aligns with the viewport top.
    static func clampedScrollOffsetPinningTopOfRow(
        rowIndex: Int,
        tileWidth tw: CGFloat,
        maxScroll: CGFloat
    ) -> CGFloat {
        let yTop = CGFloat(rowIndex) * tw
        return min(max(0, yTop), maxScroll)
    }

    /// Time within `[0, T]` when the plane’s vertical path crosses the tile midline, accounting for scroll `O0 → O1`.
    static func tauWhenCrossingRow(
        row: Int,
        tileWidth tw: CGFloat,
        O0: CGFloat,
        O1: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        T: TimeInterval
    ) -> TimeInterval {
        let yTileMid = CGFloat(row) * tw + tw / 2
        return tauWhenCrossingContentY(
            contentY: yTileMid,
            O0: O0,
            O1: O1,
            startY: startY,
            endY: endY,
            T: T
        )
    }

    /// Time within `[0, T]` when the sprite **center** reaches `contentY` (scroll content coordinates),
    /// given linear sprite motion and scroll `O0 → O1`.
    static func tauWhenCrossingContentY(
        contentY: CGFloat,
        O0: CGFloat,
        O1: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        T: TimeInterval
    ) -> TimeInterval {
        let num = contentY - O0 - startY
        let den = (endY - startY) + (O1 - O0)
        guard abs(den) > 0.5 else {
            return T * TimeInterval((contentY - startY) / (endY - startY))
        }
        let p = num / den
        return T * TimeInterval(max(0, min(1, p)))
    }

    /// Runs scroll + sprite timeline and fires `advanceBombDrop` at demo-aligned beats (player only).
    @MainActor
    static func run(
        store: GameStore,
        proxy: ScrollViewProxy,
        viewportSize: CGSize,
        updateFlightSpec: @MainActor (LiveBomberFlightSpec?) -> Void
    ) async {
        guard store.state.currentTurn == .player else { return }
        guard case .play(.bombingDrops(_, let anchor, _)) = store.state.phase else { return }

        let tw = floor(BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width))
        let hp = BoardGridMetrics.horizontalPadding
        let col = anchor.col
        let cx = hp + CGFloat(col) * tw + tw / 2
        let sprite = tw * Self.spriteTileFactor
        let half = sprite / 2
        let startY = viewportSize.height + half + 28
        let endY = -half - 28
        let T = Self.flightDuration

        let drops = Rules.bombingPositions(target: anchor, attacker: .player)

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardDuration)) {
            proxy.scrollTo("row-6", anchor: .bottom)
        }
        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardDuration))

        guard !Task.isCancelled else { return }
        guard store.state.currentTurn == .player,
              case .play(.bombingDrops(_, let anchor2, _)) = store.state.phase,
              anchor2 == anchor else { return }

        // Match `BoardView` scroll content height (`rowCount` × tile width; no negative bottom padding).
        let contentH = CGFloat(Zones.rowCount) * tw
        let maxScroll = max(0, contentH - viewportSize.height)
        let O0 = Self.clampedScrollOffsetPinningBottomOfRow(
            rowIndex: 6,
            tileWidth: tw,
            viewportHeight: viewportSize.height,
            maxScroll: maxScroll
        )
        let O1: CGFloat = 0

        let spec = LiveBomberFlightSpec(
            startTime: Date(),
            duration: T,
            cx: cx,
            startY: startY,
            endY: endY,
            halfHeight: half,
            O0: O0
        )
        updateFlightSpec(spec)

        withAnimation(.linear(duration: T)) {
            proxy.scrollTo("row-0", anchor: .top)
        }

        var previousTau: TimeInterval = 0
        for pos in drops {
            guard !Task.isCancelled else { break }
            let targetTau = Self.tauWhenCrossingRow(
                row: pos.row,
                tileWidth: tw,
                O0: O0,
                O1: O1,
                startY: startY,
                endY: endY,
                T: T
            )
            let delta = max(0, targetTau - previousTau)
            previousTau = targetTau
            if delta > 0 {
                try? await Task.sleep(for: .seconds(delta))
            }
            guard !Task.isCancelled else { break }
            store.send(.advanceBombDrop)
        }

        let remaining = max(0, T - previousTau)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

        updateFlightSpec(nil)
    }
}

// MARK: - Opponent bomber

/// Mirrors `LivePlayerBomberFlight` for the AI: pin row **6** by its top, scroll to the
/// bottom row while `bomber_transparent` flies **south** (180°), with `advanceBombDrop`
/// at each drop row crossing — same scroll model as `LiveOpponentMissileFlight`.
enum LiveOpponentBomberFlight {
    static let scrollToMidBoardDuration: TimeInterval = LivePlayerBomberFlight.scrollToMidBoardDuration
    static let flightDuration: TimeInterval = LivePlayerBomberFlight.flightDuration
    static let spriteTileFactor: CGFloat = LivePlayerBomberFlight.spriteTileFactor

    private static var bottomRowScrollId: String { "row-\(Zones.rowCount - 1)" }

    @MainActor
    static func run(
        store: GameStore,
        proxy: ScrollViewProxy,
        viewportSize: CGSize,
        updateFlightSpec: @MainActor (LiveBomberFlightSpec?) -> Void
    ) async {
        guard store.state.currentTurn == .opponent else { return }
        guard case .play(.bombingDrops(_, let anchor, _)) = store.state.phase else { return }

        let tw = floor(BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width))
        let hp = BoardGridMetrics.horizontalPadding
        let col = anchor.col
        let cx = hp + CGFloat(col) * tw + tw / 2
        let sprite = tw * Self.spriteTileFactor
        let half = sprite / 2
        let startY = -half - 28
        let endY = viewportSize.height + half + 28
        let T = Self.flightDuration

        let drops = Rules.bombingPositions(target: anchor, attacker: .opponent)

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardDuration)) {
            proxy.scrollTo("row-6", anchor: .top)
        }
        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardDuration))

        guard !Task.isCancelled else { return }
        guard store.state.currentTurn == .opponent,
              case .play(.bombingDrops(_, let anchor2, _)) = store.state.phase,
              anchor2 == anchor else { return }

        let contentH = CGFloat(Zones.rowCount) * tw
        let maxScroll = max(0, contentH - viewportSize.height)
        let O0 = LivePlayerBomberFlight.clampedScrollOffsetPinningTopOfRow(
            rowIndex: 6,
            tileWidth: tw,
            maxScroll: maxScroll
        )
        let O1 = LivePlayerBomberFlight.clampedScrollOffsetPinningBottomOfRow(
            rowIndex: Zones.rowCount - 1,
            tileWidth: tw,
            viewportHeight: viewportSize.height,
            maxScroll: maxScroll
        )

        let spec = LiveBomberFlightSpec(
            startTime: Date(),
            duration: T,
            cx: cx,
            startY: startY,
            endY: endY,
            halfHeight: half,
            O0: O0,
            missileFliesDownward: true,
            spriteRotationDegrees: 180
        )
        updateFlightSpec(spec)

        withAnimation(.linear(duration: T)) {
            proxy.scrollTo(Self.bottomRowScrollId, anchor: .bottom)
        }

        var previousTau: TimeInterval = 0
        for pos in drops {
            guard !Task.isCancelled else { break }
            let targetTau = LivePlayerBomberFlight.tauWhenCrossingRow(
                row: pos.row,
                tileWidth: tw,
                O0: O0,
                O1: O1,
                startY: startY,
                endY: endY,
                T: T
            )
            let delta = max(0, targetTau - previousTau)
            previousTau = targetTau
            if delta > 0 {
                try? await Task.sleep(for: .seconds(delta))
            }
            guard !Task.isCancelled else { break }
            store.send(.advanceBombDrop)
        }

        let remaining = max(0, T - previousTau)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

        updateFlightSpec(nil)
    }
}

// MARK: - Player missile (non-intercepted)

/// Same scroll + vertical sprite path as `LivePlayerBomberFlight`; the full X-pattern
/// resolves at once (`commitMissileFlightStrike`) when the missile **nose** reaches the
/// bottom edge of the anchor tile (no fly-over past the destination).
enum LivePlayerMissileFlight {
    static let scrollToMidBoardDuration: TimeInterval = LivePlayerBomberFlight.scrollToMidBoardDuration
    static let flightDuration: TimeInterval = LivePlayerBomberFlight.flightDuration
    static let spriteTileFactor: CGFloat = LivePlayerBomberFlight.spriteTileFactor

    @MainActor
    static func run(
        store: GameStore,
        proxy: ScrollViewProxy,
        viewportSize: CGSize,
        updateFlightSpec: @MainActor (LiveBomberFlightSpec?) -> Void
    ) async {
        guard store.state.currentTurn == .player else { return }
        guard case .play(.missileFlight(_, let anchor, let attacker)) = store.state.phase,
              attacker == .player else { return }

        let tw = floor(BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width))
        let hp = BoardGridMetrics.horizontalPadding
        let col = anchor.col
        let cx = hp + CGFloat(col) * tw + tw / 2
        let sprite = tw * Self.spriteTileFactor
        let half = sprite / 2
        let startY = viewportSize.height + half + 28
        let endY = -half - 28
        let T = Self.flightDuration

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardDuration)) {
            proxy.scrollTo("row-6", anchor: .bottom)
        }
        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardDuration))

        guard !Task.isCancelled else { return }
        guard store.state.currentTurn == .player,
              case .play(.missileFlight(_, let anchor2, let attacker2)) = store.state.phase,
              attacker2 == .player,
              anchor2 == anchor else { return }

        let contentH = CGFloat(Zones.rowCount) * tw
        let maxScroll = max(0, contentH - viewportSize.height)
        let O0 = LivePlayerBomberFlight.clampedScrollOffsetPinningBottomOfRow(
            rowIndex: 6,
            tileWidth: tw,
            viewportHeight: viewportSize.height,
            maxScroll: maxScroll
        )
        let O1: CGFloat = 0

        let spec = LiveBomberFlightSpec(
            startTime: Date(),
            duration: T,
            cx: cx,
            startY: startY,
            endY: endY,
            halfHeight: half,
            O0: O0,
            missileFliesDownward: false,
            spriteRotationDegrees: 0
        )
        updateFlightSpec(spec)

        withAnimation(.linear(duration: T)) {
            proxy.scrollTo("row-0", anchor: .top)
        }

        // Impact when the nose (top of sprite, flying upward) meets the bottom edge of the anchor tile.
        let contentYCenterAtImpact = CGFloat(anchor.row + 1) * tw + half
        let impactTau = LivePlayerBomberFlight.tauWhenCrossingContentY(
            contentY: contentYCenterAtImpact,
            O0: O0,
            O1: O1,
            startY: startY,
            endY: endY,
            T: T
        )
        if impactTau > 0 {
            try? await Task.sleep(for: .seconds(impactTau))
        }

        guard !Task.isCancelled else { return }
        guard store.state.currentTurn == .player,
              case .play(.missileFlight(_, _, let attacker3)) = store.state.phase,
              attacker3 == .player else { return }

        store.send(.commitMissileFlightStrike)
        // Hide the sprite as soon as impacts appear — no trailing glide after detonation.
        updateFlightSpec(nil)
    }
}

// MARK: - Opponent missile (non-intercepted)

/// Player missile path mirrored: pin row 6 by its top, linear scroll to the bottom row while the
/// missile sprite flies downward from the north; impact when the nose meets the top edge of the anchor tile.
enum LiveOpponentMissileFlight {
    static let scrollToMidBoardDuration: TimeInterval = LivePlayerBomberFlight.scrollToMidBoardDuration
    static let flightDuration: TimeInterval = LivePlayerBomberFlight.flightDuration
    static let spriteTileFactor: CGFloat = LivePlayerBomberFlight.spriteTileFactor

    private static var bottomRowScrollId: String { "row-\(Zones.rowCount - 1)" }

    @MainActor
    static func run(
        store: GameStore,
        proxy: ScrollViewProxy,
        viewportSize: CGSize,
        updateFlightSpec: @MainActor (LiveBomberFlightSpec?) -> Void
    ) async {
        guard store.state.currentTurn == .opponent else { return }
        guard case .play(.missileFlight(_, let anchor, let attacker)) = store.state.phase,
              attacker == .opponent else { return }

        let tw = floor(BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width))
        let hp = BoardGridMetrics.horizontalPadding
        let col = anchor.col
        let cx = hp + CGFloat(col) * tw + tw / 2
        let sprite = tw * Self.spriteTileFactor
        let half = sprite / 2
        let startY = -half - 28
        let endY = viewportSize.height + half + 28
        let T = Self.flightDuration

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardDuration)) {
            proxy.scrollTo("row-6", anchor: .top)
        }
        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardDuration))

        guard !Task.isCancelled else { return }
        guard store.state.currentTurn == .opponent,
              case .play(.missileFlight(_, let anchor2, let attacker2)) = store.state.phase,
              attacker2 == .opponent,
              anchor2 == anchor else { return }

        let contentH = CGFloat(Zones.rowCount) * tw
        let maxScroll = max(0, contentH - viewportSize.height)
        let O0 = LivePlayerBomberFlight.clampedScrollOffsetPinningTopOfRow(
            rowIndex: 6,
            tileWidth: tw,
            maxScroll: maxScroll
        )
        let O1 = LivePlayerBomberFlight.clampedScrollOffsetPinningBottomOfRow(
            rowIndex: Zones.rowCount - 1,
            tileWidth: tw,
            viewportHeight: viewportSize.height,
            maxScroll: maxScroll
        )

        let spec = LiveBomberFlightSpec(
            startTime: Date(),
            duration: T,
            cx: cx,
            startY: startY,
            endY: endY,
            halfHeight: half,
            O0: O0,
            missileFliesDownward: true,
            spriteRotationDegrees: 180
        )
        updateFlightSpec(spec)

        withAnimation(.linear(duration: T)) {
            proxy.scrollTo(Self.bottomRowScrollId, anchor: .bottom)
        }

        // Impact when the nose (bottom of sprite, flying downward) meets the top edge of the anchor tile.
        let contentYCenterAtImpact = CGFloat(anchor.row) * tw - half
        let impactTau = LivePlayerBomberFlight.tauWhenCrossingContentY(
            contentY: contentYCenterAtImpact,
            O0: O0,
            O1: O1,
            startY: startY,
            endY: endY,
            T: T
        )
        if impactTau > 0 {
            try? await Task.sleep(for: .seconds(impactTau))
        }

        guard !Task.isCancelled else { return }
        guard store.state.currentTurn == .opponent,
              case .play(.missileFlight(_, _, let attacker3)) = store.state.phase,
              attacker3 == .opponent else { return }

        store.send(.commitMissileFlightStrike)
        updateFlightSpec(nil)
    }
}
