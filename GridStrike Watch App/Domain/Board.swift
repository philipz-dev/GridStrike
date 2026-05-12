//
//  Board.swift
//  GridStrike Watch App
//
//  Mutable, value-type board state. All cell lookups go through GridPosition.
//

import Foundation

struct Board: Equatable {
    var marks: [GridPosition: Unit]
    var bomberRotations: [GridPosition: Double]
    var didApplyEnemySpawn: Bool

    init(
        marks: [GridPosition: Unit] = [:],
        bomberRotations: [GridPosition: Double] = [:],
        didApplyEnemySpawn: Bool = false
    ) {
        self.marks = marks
        self.bomberRotations = bomberRotations
        self.didApplyEnemySpawn = didApplyEnemySpawn
    }

    static let empty = Board()

    func unit(at position: GridPosition) -> Unit? { marks[position] }

    /// Returns the coastguard column of the requested side, if its coastguard is
    /// still on the board. If multiple cruisers sit on the same coastguard water row
    /// (DEBUG fill), this returns the **first** column in scan order — prefer
    /// `hasCoastguardOnCoastRow(of:column:)` for interception rules.
    func coastguardColumn(of side: Side) -> Int? {
        let row = Zones.coastguardRow(of: side)
        for col in Zones.allColumns where marks[GridPosition(row, col)] == .coastguard {
            return col
        }
        return nil
    }

    /// True when a live coastguard occupies this column on the defender's coastguard water row.
    func hasCoastguardOnCoastRow(of defender: Side, column: Int) -> Bool {
        let row = Zones.coastguardRow(of: defender)
        return unit(at: GridPosition(row, column)) == .coastguard
    }

    /// Back-compat alias for the player-attacks-opponent code paths.
    var enemyCoastguardColumn: Int? { coastguardColumn(of: .opponent) }

    /// Removes a launcher unit (bomber/missile) from `attacker`'s home grass after
    /// it has fired. Symmetric replacement for the old "remove southern unit" helper.
    mutating func removeLauncher(at position: GridPosition, requiring unit: Unit, attacker: Side) {
        guard Zones.grassRows(of: attacker).contains(position.row) else { return }
        guard marks[position] == unit else { return }
        marks.removeValue(forKey: position)
        if unit == .bomber { bomberRotations.removeValue(forKey: position) }
    }

    /// Back-compat alias used by older code paths that always assumed `.player`.
    mutating func removeSouthernUnit(at position: GridPosition, requiring unit: Unit) {
        removeLauncher(at: position, requiring: unit, attacker: .player)
    }
}
