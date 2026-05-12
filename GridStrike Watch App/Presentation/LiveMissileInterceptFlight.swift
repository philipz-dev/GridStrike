//
//  LiveMissileInterceptFlight.swift
//  GridStrike Watch App
//
//  Same timing and motion as `Demo_Coastguard` after the mid-board scroll: pinned row-6
//  bottom, flying sprite (`missiletransparent` or `bomber_transparent` from `BoardView`),
//  intercept explosion + coastguard fade + banner.
//

import SwiftUI

struct LiveMissileFlightSpec: Equatable {
    let startTime: Date
    let duration: TimeInterval
    let cx: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let halfHeight: CGFloat
    /// Opponent missile shot down by the player coastguard: sprite enters from the north.
    let missileFliesDownward: Bool
    let spriteRotationDegrees: Double

    init(
        startTime: Date,
        duration: TimeInterval,
        cx: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        halfHeight: CGFloat,
        missileFliesDownward: Bool = false,
        spriteRotationDegrees: Double = 0
    ) {
        self.startTime = startTime
        self.duration = duration
        self.cx = cx
        self.startY = startY
        self.endY = endY
        self.halfHeight = halfHeight
        self.missileFliesDownward = missileFliesDownward
        self.spriteRotationDegrees = spriteRotationDegrees
    }
}

enum LiveMissileInterceptFlight {
    /// Mirrors `Demo_Coastguard` (missile run segment).
    static let scrollToMidBoardDuration: TimeInterval = 1.1
    static let missileFlightDuration: TimeInterval = 3.35
    static let missileFlightSpriteTileFactor: CGFloat = 1.22
    static let interceptExplosionGrowDuration: TimeInterval = 0.14 * 1.2
    static let interceptExplosionFadeDuration: TimeInterval = 0.24
    static let interceptCoastguardFadeDuration: TimeInterval = (2.4 * 1.2) / 2
    static let delayBeforeInterceptBanner: TimeInterval = 1
    /// Fly sprite dismissed when centre crosses this row (same as demo).
    static let missileDismissRow = 6

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

    static func tileCentreScreen(
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

    /// Runs scroll + missile + intercept overlays (matches `Demo_Coastguard.runSequence` tail).
    @MainActor
    static func run(
        proxy: ScrollViewProxy,
        viewportSize: CGSize,
        anchorColumn: Int,
        updateMissileSpec: @MainActor (LiveMissileFlightSpec?) -> Void,
        updateInterceptExplosion: @MainActor (_ show: Bool, _ scale: CGFloat, _ opacity: CGFloat) -> Void,
        updateInterceptCoastguard: @MainActor (_ show: Bool, _ opacity: CGFloat) -> Void,
        updateInterceptBanner: @MainActor (Bool) -> Void
    ) async {
        let tw = BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width)
        let hp = BoardGridMetrics.horizontalPadding

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardDuration)) {
            proxy.scrollTo("row-6", anchor: .bottom)
        }
        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardDuration))

        let contentH = CGFloat(Zones.rowCount) * tw
        let maxScroll = max(0, contentH - viewportSize.height)
        let O0 = Self.clampedScrollOffsetPinningBottomOfRow(
            rowIndex: 6,
            tileWidth: tw,
            viewportHeight: viewportSize.height,
            maxScroll: maxScroll
        )

        let cx = hp + CGFloat(anchorColumn) * tw + tw / 2
        let sprite = tw * Self.missileFlightSpriteTileFactor
        let half = sprite / 2
        let startY = viewportSize.height + half + 28
        let endY = -half - 28
        let T = Self.missileFlightDuration

        let flightStart = Date()
        updateMissileSpec(
            LiveMissileFlightSpec(
                startTime: flightStart,
                duration: T,
                cx: cx,
                startY: startY,
                endY: endY,
                halfHeight: half
            )
        )

        func tauWhenMissileCentreCrossesContentYMid(_ contentYMid: CGFloat) -> TimeInterval {
            let targetScreenY = contentYMid - O0
            let den = endY - startY
            guard abs(den) > 1 else { return 0 }
            let u = (targetScreenY - startY) / den
            return max(0, min(T, T * TimeInterval(u)))
        }

        let yDismissMid = CGFloat(Self.missileDismissRow) * tw + tw / 2
        var tauDismiss = tauWhenMissileCentreCrossesContentYMid(yDismissMid)
        tauDismiss = max(0, min(T, tauDismiss))

        let elapsedBeforeWait = Date().timeIntervalSince(flightStart)
        let waitDismiss = max(0, tauDismiss - elapsedBeforeWait)
        if waitDismiss > 0 {
            try? await Task.sleep(for: .seconds(waitDismiss))
        }

        updateMissileSpec(nil)

        updateInterceptExplosion(true, 0.25, 1)
        updateInterceptCoastguard(true, 0)
        withAnimation(.easeIn(duration: Self.interceptCoastguardFadeDuration)) {
            updateInterceptCoastguard(true, 1)
        }

        await Task.yield()
        withAnimation(.easeOut(duration: Self.interceptExplosionGrowDuration)) {
            updateInterceptExplosion(true, 2.0, 1)
        }
        try? await Task.sleep(for: .seconds(Self.interceptExplosionGrowDuration))

        withAnimation(.easeOut(duration: Self.interceptExplosionFadeDuration)) {
            updateInterceptExplosion(true, 2.0, 0)
        }
        try? await Task.sleep(for: .seconds(Self.interceptExplosionFadeDuration))
        updateInterceptExplosion(false, 0.25, 1)

        let totalElapsed = Date().timeIntervalSince(flightStart)
        let remaining = max(0, T - totalElapsed)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

        try? await Task.sleep(for: .seconds(Self.delayBeforeInterceptBanner))
        withAnimation(.easeOut(duration: 0.2)) {
            updateInterceptBanner(true)
        }
    }

    /// Same timing beats as `run`, but scroll + missile path mirror `LiveOpponentMissileFlight`:
    /// pin row 6 by its **top**, missile flies south (rotated) toward the player coastguard row.
    @MainActor
    static func runMirrored(
        proxy: ScrollViewProxy,
        viewportSize: CGSize,
        anchorColumn: Int,
        updateMissileSpec: @MainActor (LiveMissileFlightSpec?) -> Void,
        updateInterceptExplosion: @MainActor (_ show: Bool, _ scale: CGFloat, _ opacity: CGFloat) -> Void,
        updateInterceptCoastguard: @MainActor (_ show: Bool, _ opacity: CGFloat) -> Void,
        updateInterceptBanner: @MainActor (Bool) -> Void
    ) async {
        let tw = BoardGridMetrics.tileWidth(forContainerWidth: viewportSize.width)
        let hp = BoardGridMetrics.horizontalPadding

        withAnimation(.easeInOut(duration: Self.scrollToMidBoardDuration)) {
            proxy.scrollTo("row-6", anchor: .top)
        }
        try? await Task.sleep(for: .seconds(Self.scrollToMidBoardDuration))

        let contentH = CGFloat(Zones.rowCount) * tw
        let maxScroll = max(0, contentH - viewportSize.height)
        let O0 = LivePlayerBomberFlight.clampedScrollOffsetPinningTopOfRow(
            rowIndex: 6,
            tileWidth: tw,
            maxScroll: maxScroll
        )

        let cx = hp + CGFloat(anchorColumn) * tw + tw / 2
        let sprite = tw * Self.missileFlightSpriteTileFactor
        let half = sprite / 2
        let startY = -half - 28
        let endY = viewportSize.height + half + 28
        let T = Self.missileFlightDuration

        let flightStart = Date()
        updateMissileSpec(
            LiveMissileFlightSpec(
                startTime: flightStart,
                duration: T,
                cx: cx,
                startY: startY,
                endY: endY,
                halfHeight: half,
                missileFliesDownward: true,
                spriteRotationDegrees: 180
            )
        )

        func tauWhenMissileCentreCrossesContentYMid(_ contentYMid: CGFloat) -> TimeInterval {
            let targetScreenY = contentYMid - O0
            let den = endY - startY
            guard abs(den) > 1 else { return 0 }
            let u = (targetScreenY - startY) / den
            return max(0, min(T, T * TimeInterval(u)))
        }

        let dismissRow = Zones.shotDownRow(attacker: .opponent)
        let yDismissMid = CGFloat(dismissRow) * tw + tw / 2
        var tauDismiss = tauWhenMissileCentreCrossesContentYMid(yDismissMid)
        tauDismiss = max(0, min(T, tauDismiss))

        let elapsedBeforeWait = Date().timeIntervalSince(flightStart)
        let waitDismiss = max(0, tauDismiss - elapsedBeforeWait)
        if waitDismiss > 0 {
            try? await Task.sleep(for: .seconds(waitDismiss))
        }

        updateMissileSpec(nil)

        updateInterceptExplosion(true, 0.25, 1)
        updateInterceptCoastguard(true, 0)
        withAnimation(.easeIn(duration: Self.interceptCoastguardFadeDuration)) {
            updateInterceptCoastguard(true, 1)
        }

        await Task.yield()
        withAnimation(.easeOut(duration: Self.interceptExplosionGrowDuration)) {
            updateInterceptExplosion(true, 2.0, 1)
        }
        try? await Task.sleep(for: .seconds(Self.interceptExplosionGrowDuration))

        withAnimation(.easeOut(duration: Self.interceptExplosionFadeDuration)) {
            updateInterceptExplosion(true, 2.0, 0)
        }
        try? await Task.sleep(for: .seconds(Self.interceptExplosionFadeDuration))
        updateInterceptExplosion(false, 0.25, 1)

        let totalElapsed = Date().timeIntervalSince(flightStart)
        let remaining = max(0, T - totalElapsed)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

        try? await Task.sleep(for: .seconds(Self.delayBeforeInterceptBanner))
        withAnimation(.easeOut(duration: 0.2)) {
            updateInterceptBanner(true)
        }
    }
}
