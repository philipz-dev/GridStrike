//
//  Assets.swift
//  HQStrike Watch App
//
//  Cached `Image` references and small lookup helpers. Avoids re-doing string-based
//  asset catalog lookups inside tile rendering.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Assets {
    static let grass = Image("grass")
    static let water = Image("water")
    static let headquarters = Image("HeadquarterTile")
    static let missile = Image("MissileTile")
    /// Bomber on home grass (north or south) — opaque art with grass baked in (`bomber.png`).
    static let bomberOnGrass = Image("bomber")
    /// Bomber off-grass (shouldn’t appear on the grid in normal play) and fly-through overlays.
    static let bomberTransparent = Image("bomber_transparent")
    /// Missile fly-through overlay (`BoardView` / intercept `TimelineView` paths).
    static let missileTransparent = Image("missiletransparent")
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
    /// Full-bleed art for the win screen — painted to read with title shadows (no extra dimming layer).
    static let victoryBackground = Image("VictoryBackground")
    /// Full-bleed art for the lose screen — paired with `victoryBackground` (no extra dimming layer).
    static let defeatBackground = Image("DefeatBackground")

    /// Manual hub: full-screen camouflage + weapon picker tiles.
    static let manualMenuCamouflage = Image("ManualMenuCamouflage")
    static let manualMenuGrenade = Image("ManualMenuGrenade")
    static let manualMenuMissile = Image("ManualMenuMissile")
    static let manualMenuBomber = Image("ManualMenuBomber")
    static let manualMenuCoastguard = Image("ManualMenuCoastguard")
    /// Tactical main-menu START ASSAULT — grenade art (opaque asset on black matte).
    static let startAssaultGrenade = Image("StartAssaultGrenade")
    /// Tactical main-menu FIELD GUIDE — open book with chevron bookmark.
    static let mainMenuFieldGuide = Image("MainMenuFieldGuide")

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
            // `bomber.png` includes grass; use it on both home halves so tiles aren’t
            // punched through to black (`bomber_transparent` is only for overlays /
            // contexts that composite on top of something else).
            if Zones.isAnyGrass(position.row) {
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

    /// Decodes flight overlay bitmaps once at launch so the first `TimelineView` run avoids catalog decode on the hot path.
    static func warmFlightOverlayDecoding() {
        #if canImport(UIKit)
        _ = UIImage(named: "bomber_transparent")
        _ = UIImage(named: "missiletransparent")
        #endif
    }
}
