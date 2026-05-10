//
//  Assets.swift
//  GridStrike Watch App
//
//  Cached `Image` references and small lookup helpers. Avoids re-doing string-based
//  asset catalog lookups inside tile rendering.
//

import SwiftUI

enum Assets {
    static let grass = Image("grass")
    static let water = Image("water")
    static let headquarters = Image("HeadquarterTile")
    static let missile = Image("MissileTile")
    /// Bomber on the player’s home grass — opaque art with grass baked in (`bomber.png`).
    static let bomberOnGrass = Image("bomber")
    /// Bomber everywhere else (enemy zone, fly-through overlays): transparent silhouette.
    static let bomberTransparent = Image("bomber_transparent")
    static let coastguard = Image("CruiserTile")
    /// Wreck art rendered on a coastguard tile after the cruiser is destroyed
    /// (grenade hit, or a missile diagonal landing on the coastguard row).
    /// Replaces the regular CG art + explosion overlay so the destroyed cell
    /// is unambiguously a wreck rather than a still-active coastguard.
    static let coastguardSunk = Image("CruiserSunkTile")
    static let explosionHit = Image("ExplosionHit")
    static let explosionMiss = Image("ExplosionMiss")
    static let planeInWater = Image("PlaneInWater")
    static let missileInWater = Image("MissileInWater")
    static let splashBackground = Image("SplashBackground")
    /// Full-bleed art shown behind the Victory overlay — celebratory soldier
    /// silhouette painted to read against the dark scrim that hosts the
    /// "Victory!" label and the New game / Map buttons.
    static let victoryBackground = Image("VictoryBackground")
    /// Mirror of `victoryBackground` for the defeat path. Same composition
    /// language (single soldier, sunset sky) so the two end-game screens
    /// feel like a paired set.
    static let defeatBackground = Image("DefeatBackground")
    /// Aged parchment scroll used as the backdrop for the help/instructions
    /// sheet. Resized vertically to fit whatever text length the help page
    /// produces; horizontally clipped to the watch width.
    static let parchment = Image("Parchment")

    static func tileImage(for background: TileBackground, at position: GridPosition) -> Image {
        switch background {
        case .grass: return grass
        case .water: return water
        case .unit(let unit): return unitTileImage(unit, at: position)
        case .coastguardSunk: return coastguardSunk
        }
    }

    private static func unitTileImage(_ unit: Unit, at position: GridPosition) -> Image {
        switch unit {
        case .headquarters: return headquarters
        case .missile: return missile
        case .bomber:
            if Zones.southGrass.contains(position.row) {
                return bomberOnGrass
            }
            return bomberTransparent
        case .coastguard: return coastguard
        }
    }

    static func explosionImage(for kind: ExplosionKind) -> Image {
        switch kind {
        case .hit: return explosionHit
        case .miss: return explosionMiss
        }
    }
}
