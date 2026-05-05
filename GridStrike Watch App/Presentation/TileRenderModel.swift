//
//  TileRenderModel.swift
//  GridStrike Watch App
//
//  Equatable per-tile render data. TileView is `Equatable` over this so SwiftUI only
//  redraws tiles whose render model actually changed.
//

import Foundation

enum TileBackground: Equatable {
    case grass
    case water
    case unit(Unit)
    /// Special background for a coastguard tile whose cruiser has been
    /// destroyed. Renders the wreck artwork directly instead of layering an
    /// explosion overlay on top of plain water.
    case coastguardSunk
}

enum TileBorder: Equatable {
    case plain
    case dim
    case selected
}

enum DimMode: Equatable {
    case none
    case normal
    case coastguardOffRow
}

struct TileRenderModel: Equatable {
    let position: GridPosition
    let background: TileBackground
    let bomberRotationDegrees: Double
    let dim: DimMode
    let offCoastguardFocusRow: Bool
    let northStrikeOverlay: ExplosionKind?
    let dropOverlay: ExplosionKind?
    let waterWreck: WaterWreck?
    /// Rotation applied to the water-wreck overlay. Player wrecks (downed by enemy
    /// coastguard) sit at **45°** to suggest the angle of impact; opponent wrecks
    /// (downed by **your** coastguard) at **135°** clockwise per the latest UI spec.
    let wreckRotationDegrees: Double
    let border: TileBorder
    /// Tile is part of the orange-outlined "last turn highlight" — the AI's last
    /// impact cells, the player CG + enemy wreck after a player-side defence, or
    /// the enemy CG + player wreck after a player-attack got intercepted.
    let isLastTurnHighlight: Bool
    let isDisabled: Bool
}
