//
//  BoardGridMetrics.swift
//  GridStrike Watch App
//
//  Shared sizing so live `BoardView` and the frozen post-game map use identical tiles.
//

import SwiftUI

enum BoardGridMetrics {
    /// Matches `BoardView` horizontal gutter so tile width lines up everywhere.
    static let horizontalPadding: CGFloat = 2

    static var columnCount: Int { Zones.columnCount }
    static var rowCount: Int { Zones.rowCount }

    /// One tile square size for a measured container width (watch screen geometry).
    static func tileWidth(forContainerWidth width: CGFloat) -> CGFloat {
        max(1, (width - horizontalPadding * 2) / CGFloat(columnCount))
    }
}
