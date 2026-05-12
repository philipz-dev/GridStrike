//
//  HQStrikeDebugConfig.swift
//  HQStrike Watch App
//
//  Local-only toggles (`DEBUG` targets). Fold each back off before merging or use a
//  Release Archive so none of these paths ship.
//

import Foundation

#if DEBUG
enum HQStrikeDebug {
    /// When **true**, the enemy coastguard cruiser is drawn on its water tile (row 5)
    /// during play instead of blending in as fogged water — handy for probing every
    /// intercept / grenade column. Default **false** so normal debug runs stay fair.
    static var showEnemyCoastguardPlacement = false

    /// When **true**, every opponent placement on rows **0…5** is drawn on the live
    /// battlefield during play (“full cheat sheet”).
    static var showAllEnemyPiecesOnPlayfield = true
    

    /// Frozen post-game map: **true** = draw opponent unit sprites north of the narrows,
    /// same as round start (**default**); **false** = terrain-only in rows **0…5** on that
    /// screen for fog-style UI testing (player half still drawn from snapshot).
    static var showAllEnemyObjectsOnPostGameMap = true

    /// When **true**, after setup confirm every column on the player coastguard row (**8**)
    /// gets a `.coastguard` mark. Interception uses `Board.hasCoastguardOnCoastRow` per column
    /// so each cruiser can shoot down column-aligned bombers/missiles like the real game.
    static var fillRow8WithPlayerCoastguards = false

    /// When **true**, the computer never picks strikes whose footprint includes a tile that
    /// currently has a **player** `.coastguard` (grenade tap, bomber column, missile X).
    static var opponentNeverAttacksPlayerCoastguardTiles = true

    /// When **true**, the opponent prioritises tapping a **bomber** or **missile** launcher
    /// on its idle turn before grenades or grass hunts (`SmartOpponent` + `RandomOpponent`).
    static var computerUsesBomberAndMissilesFirst = true
}
#endif

/// Release-safe wrapper so opponent code can call one API without `#if DEBUG` at every site.
enum HQStrikeOpponentDebugStrikeFilter {
    /// **false** iff debug mode asks the AI to avoid player coastguard tiles *and* at least
    /// one cell in `cells` currently hosts `Unit.coastguard` on the live board.
    static func opponentMayStrike(board: Board, footprint cells: [GridPosition]) -> Bool {
        #if DEBUG
        guard HQStrikeDebug.opponentNeverAttacksPlayerCoastguardTiles else { return true }
        return !cells.contains { board.unit(at: $0) == .coastguard }
        #else
        return true
        #endif
    }

    /// When **true** (DEBUG only), opponent idle turns try bomber/missile taps before grenades.
    static var prefersBomberAndMissileFirst: Bool {
        #if DEBUG
        return HQStrikeDebug.computerUsesBomberAndMissilesFirst
        #else
        return false
        #endif
    }
}
