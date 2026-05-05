//
//  Rules.swift
//  GridStrike Watch App
//
//  Pure rule predicates and attack geometry. Easy to unit-test without any UI.
//  Every helper is parameterised on the attacking `Side` so the same logic drives
//  both the player's and the AI's offensives.
//

import Foundation

enum Rules {
    // MARK: - Attack footprints

    /// 3-drop column starting at `target` and walking back toward the attacker's
    /// home — i.e. drops fall *away* from the attacker. Out-of-bounds rows are
    /// filtered out.
    static func bombingPositions(target: GridPosition, attacker: Side) -> [GridPosition] {
        var result: [GridPosition] = []
        result.reserveCapacity(3)
        let direction: Int = (attacker == .player) ? -1 : +1
        for i in 0..<3 {
            let r = target.row + direction * i
            if Zones.allRows.contains(r) {
                result.append(GridPosition(r, target.col))
            }
        }
        return result
    }

    /// Missile X-pattern: the targeted tile + its four diagonal neighbours
    /// (top-left, top-right, bottom-right, bottom-left). Symmetric, so `attacker`
    /// is unused; kept in the signature for API stability with bomber rules.
    ///
    /// The anchor can sit anywhere on the defender's grass, so diagonals from a
    /// corner column or a back-row anchor can fall off the grid. We drop those
    /// out-of-bounds cells here — they show no explosion and never feed the
    /// reducer's overlay maps. Diagonals that fall into the defender's water /
    /// coastguard row are kept and resolved like any other cell: a hit on the
    /// coastguard, a miss on plain water.
    static func missilePositions(anchor pos: GridPosition, attacker: Side) -> [GridPosition] {
        _ = attacker
        let candidates = [
            pos,
            GridPosition(pos.row - 1, pos.col - 1),
            GridPosition(pos.row - 1, pos.col + 1),
            GridPosition(pos.row + 1, pos.col + 1),
            GridPosition(pos.row + 1, pos.col - 1),
        ]
        return candidates.filter {
            Zones.allRows.contains($0.row) && Zones.allColumns.contains($0.col)
        }
    }

    // MARK: - Coastguard interception

    /// Bomber: intercepted when the column matches the defender's coastguard column AND
    /// at least one drop cell falls past that water row (i.e. on the defender's grass).
    static func bomberIntercepted(board: Board, target: GridPosition, attacker: Side) -> Bool {
        let defender = attacker.opposite
        guard let coastCol = board.coastguardColumn(of: defender), coastCol == target.col else { return false }
        let coastRow = Zones.coastguardRow(of: defender)
        return bombingPositions(target: target, attacker: attacker).contains { pos in
            switch attacker {
            case .player: return pos.row < coastRow      // drops go up → past = strictly less
            case .opponent: return pos.row > coastRow    // drops go down → past = strictly greater
            }
        }
    }

    /// Missile X-pattern interception: the salvo is shot down only when the
    /// **pointed-at centre tile** sits in the defender's coastguard column.
    /// Diagonals straddling that column do **not** trigger interception.
    static func missileIntercepted(board: Board, anchor: GridPosition, attacker: Side) -> Bool {
        let defender = attacker.opposite
        guard let coastCol = board.coastguardColumn(of: defender) else { return false }
        return anchor.col == coastCol
    }

    // MARK: - Victory

    /// True iff any of the affected positions hosts the requested side's HQ.
    static func includesHQ(_ board: Board, of side: Side, in positions: [GridPosition]) -> Bool {
        let grass = Zones.grassRows(of: side)
        return positions.contains { pos in
            grass.contains(pos.row) && board.unit(at: pos) == .headquarters
        }
    }

    // MARK: - Back-compat (player-attacks-opponent only)

    static func bombingPositions(target: GridPosition) -> [GridPosition] {
        bombingPositions(target: target, attacker: .player)
    }

    static func missilePositions(lowerLeft pos: GridPosition) -> [GridPosition] {
        missilePositions(anchor: pos, attacker: .player)
    }

    static func bomberIntercepted(board: Board, target: GridPosition) -> Bool {
        bomberIntercepted(board: board, target: target, attacker: .player)
    }

    static func missileIntercepted(board: Board, lowerLeft: GridPosition) -> Bool {
        missileIntercepted(board: board, anchor: lowerLeft, attacker: .player)
    }

    static func includesEnemyHQ(_ board: Board, in positions: [GridPosition]) -> Bool {
        includesHQ(board, of: .opponent, in: positions)
    }
}
