//
//  GridPosition.swift
//  HQStrike Watch App
//
//  Type-safe (row, col) replacement for the legacy "row_col" String keys.
//

import Foundation

struct GridPosition: Hashable, Equatable, Comparable {
    let row: Int
    let col: Int

    init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }

    static func < (lhs: GridPosition, rhs: GridPosition) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        return lhs.col < rhs.col
    }
}

extension GridPosition: CustomStringConvertible {
    var description: String { "\(row)_\(col)" }
}
