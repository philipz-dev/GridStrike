//
//  GridStrikeDebugConfig.swift
//  GridStrike Watch App
//
//  Local-only toggles (`DEBUG` targets). Fold each back off before merging or use a
//  Release Archive so none of these paths ship.
//

import Foundation

#if DEBUG
enum GridStrikeDebug {
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
}
#endif
