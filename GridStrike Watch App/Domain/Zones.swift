//
//  Zones.swift
//  HQStrike Watch App
//
//  All grid coordinates and ranges live here. Single source of truth — no more magic
//  numbers scattered across the view layer. Helpers come in two flavours: absolute
//  ones (kept for the original "player attacks opponent" code paths) and Side-
//  parametric ones (used by the symmetric reducer/renderer that drives the AI turn).
//

import Foundation

enum Zones {
    static let rowCount = 14
    static let columnCount = 5
    static let allRows: ClosedRange<Int> = 0...13
    static let allColumns: ClosedRange<Int> = 0...4

    /// 0…4 — northern grass (opponent zone, hidden during play).
    static let northGrass: ClosedRange<Int> = 0...4
    /// 5…8 — water rows.
    static let waterRows: ClosedRange<Int> = 5...8
    /// 9…13 — southern grass (player zone).
    static let southGrass: ClosedRange<Int> = 9...13

    /// Player's coastguard placement row (during setup).
    static let coastguardPlayerRow = 8
    /// Enemy coastguard sits one water row south of the top grass.
    static let coastguardEnemyRow = 5
    /// Plane / MissileInWater overlays sit one row south of the enemy coastguard
    /// (the wreckage drifts down toward the player after a shoot-down).
    static let planeInWaterRow = 6

    /// Row to scroll to when the player is about to attack — keeps the opponent's
    /// half (HQ row + their coastguard) in view.
    static let opponentOverviewRow = 2
    /// Row to scroll to when the opponent is about to attack — keeps the player's
    /// half (their coastguard + grass) in view so they can watch the AI's impact.
    static let playerOverviewRow = 11

    /// Scroll anchor between rows 7 and 8 — opponent wreck row + player CG row.
    /// Centres both on screen after the **player's** coastguard intercepts an
    /// enemy plane / missile.
    static let playerDefenseSeamID = "seam-7-8"
    /// Scroll anchor between rows 5 and 6 — enemy CG row + player wreck row.
    /// Centres both on screen after the **enemy's** coastguard intercepts a
    /// player-launched plane / missile.
    static let opponentDefenseSeamID = "seam-5-6"

    /// Returns the seam id that centres the defender's coastguard row and the
    /// adjacent attacker's wreck row on screen.
    static func coastguardDefenseSeamID(defender: Side) -> String {
        switch defender {
        case .player:   return playerDefenseSeamID    // wreck on row 7, CG on row 8
        case .opponent: return opponentDefenseSeamID  // CG on row 5, wreck on row 6
        }
    }

    /// Allowed rows for choosing a bombing target. The full opponent grass is
    /// legal — back-row anchors (rows 0, 1) walk drops off the top of the
    /// board, which `Rules.bombingPositions` filters out. The human is free to
    /// pay that cost; the AI uses `safeBombingTargetRows(attacker:)` to stay
    /// inside the all-3-drops-land window.
    static let bombingTargetRows: ClosedRange<Int> = 0...4
    /// Allowed centre rows for the missile X-pattern (player attacker default).
    /// The full opponent grass — corner-row diagonals clip out of bounds and
    /// front-row (row 4) diagonals spill into the coastguard water row; both
    /// cases are handled by `Rules.missilePositions`.
    static let missileTargetRows: ClosedRange<Int> = 0...4
    /// Allowed centre columns for the missile X-pattern. Corner columns (0, 4)
    /// produce only three in-bounds salvo cells because two diagonals fall off
    /// the side of the board.
    static let missileTargetColumns: ClosedRange<Int> = 0...4
    /// Subset of `missileTargetColumns` whose anchor only delivers 3 of the
    /// 5 X-pattern cells (the two off-board diagonals are dropped). Single
    /// source of truth so the AI doesn't have to recompute "is this a
    /// corner?" by hand in every targeting heuristic.
    static let missileCornerColumns: Set<Int> = [0, 4]

    /// Opponent missile anchors on the player's grass to skip: corner columns waste
    /// side diagonals; **rows 9 and 13** waste diagonals into water or off the board
    /// (symmetric to player anchors on rows **4** and **0** attacking north).
    static func isWastedOpponentMissileAnchor(_ pos: GridPosition) -> Bool {
        if missileCornerColumns.contains(pos.col) { return true }
        if pos.row == 9 || pos.row == 13 { return true }
        return false
    }

    /// Rows the player can grenade-strike during play. Includes the enemy grass (0–4) and the enemy
    /// coastguard's water row (5) so the player can take out the coastguard before mounting a column attack.
    static let grenadeTargetRows: ClosedRange<Int> = 0...5

    static func isNorthGrass(_ row: Int) -> Bool { northGrass.contains(row) }
    static func isWater(_ row: Int) -> Bool { waterRows.contains(row) }
    static func isSouthGrass(_ row: Int) -> Bool { southGrass.contains(row) }
    static func isAnyGrass(_ row: Int) -> Bool { isNorthGrass(row) || isSouthGrass(row) }
    static func isGrenadeTarget(_ row: Int) -> Bool { grenadeTargetRows.contains(row) }

    static func isBombingTarget(_ pos: GridPosition) -> Bool {
        bombingTargetRows.contains(pos.row) && allColumns.contains(pos.col)
    }

    static func isMissileTarget(_ pos: GridPosition) -> Bool {
        missileTargetRows.contains(pos.row) && missileTargetColumns.contains(pos.col)
    }

    // MARK: - Side-parametric helpers

    /// Which half of the board a tile belongs to. The two mid-water rows (6, 7) sit
    /// outside both home halves and so don't carry an owner.
    static func side(forRow row: Int) -> Side? {
        if row <= coastguardEnemyRow { return .opponent }      // 0…5
        if row >= coastguardPlayerRow { return .player }       // 8…13
        return nil                                             // 6, 7
    }

    /// Home grass for a side (where its HQ / non-coastguard units sit).
    static func grassRows(of side: Side) -> ClosedRange<Int> {
        switch side {
        case .opponent: return northGrass     // 0…4
        case .player: return southGrass       // 9…13
        }
    }

    /// Coastguard water row for a side.
    static func coastguardRow(of side: Side) -> Int {
        switch side {
        case .opponent: return coastguardEnemyRow   // 5
        case .player: return coastguardPlayerRow    // 8
        }
    }

    /// Wreckage row used when `attacker`'s plane/missile is shot down — one water
    /// row "outward" from the defender's coastguard (toward the attacker).
    /// Player attacks → wreck on row 6 (south of the enemy coastguard).
    /// Opponent attacks → wreck on row 7 (north of the player coastguard).
    static func shotDownRow(attacker: Side) -> Int {
        switch attacker {
        case .player: return 6
        case .opponent: return 7
        }
    }

    /// Rows where a grenade tap from `attacker` is valid — the defender's grass
    /// plus that defender's coastguard row.
    static func grenadeTargetRows(attacker: Side) -> ClosedRange<Int> {
        let defender = attacker.opposite
        switch defender {
        case .opponent: return 0...5    // attacker = player
        case .player: return 8...13     // attacker = opponent
        }
    }

    static func isGrenadeTarget(_ pos: GridPosition, attacker: Side) -> Bool {
        grenadeTargetRows(attacker: attacker).contains(pos.row)
    }

    /// Legal bombing-target rows for an attacker — the full defender's grass.
    /// Drops fall away from the attacker, so anchors near the defender's back
    /// row spill drops off the edge of the board; `Rules.bombingPositions`
    /// filters those, and the player is free to "waste" the missing drops by
    /// picking such an anchor.
    static func bombingTargetRows(attacker: Side) -> ClosedRange<Int> {
        switch attacker {
        case .player: return 0...4        // full opponent grass
        case .opponent: return 9...13     // full player grass
        }
    }

    /// The subset of `bombingTargetRows(attacker:)` where all three drops are
    /// guaranteed to land on the defender's grass — i.e. anchoring here never
    /// wastes a bomb on a non-existent tile. Used by the AI so it doesn't
    /// throw away drops; the human can still tap the wider legal range.
    static func safeBombingTargetRows(attacker: Side) -> ClosedRange<Int> {
        switch attacker {
        case .player: return 2...4        // drops 0/1/2 .. 2/3/4
        case .opponent: return 9...11     // drops 9/10/11 .. 11/12/13
        }
    }

    static func isBombingTarget(_ pos: GridPosition, attacker: Side) -> Bool {
        bombingTargetRows(attacker: attacker).contains(pos.row) && allColumns.contains(pos.col)
    }

    /// Allowed centre rows for an attacker's missile X-pattern — the full grass
    /// of the defender. Diagonals from a back-row anchor (row 0 / row 13) clip
    /// out of bounds; diagonals from the water-edge anchor (row 4 / row 9) spill
    /// into the coastguard water row. `Rules.missilePositions` drops the
    /// out-of-bounds cells so they're never resolved or rendered.
    static func missileTargetRows(attacker: Side) -> ClosedRange<Int> {
        switch attacker {
        case .player: return 0...4        // full opponent grass
        case .opponent: return 9...13     // full player grass
        }
    }

    static func isMissileTarget(_ pos: GridPosition, attacker: Side) -> Bool {
        missileTargetRows(attacker: attacker).contains(pos.row)
            && missileTargetColumns.contains(pos.col)
    }
}
