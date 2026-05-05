//
//  Phase.swift
//  GridStrike Watch App
//
//  Explicit state machine for the whole game flow. Replaces the loose collection of
//  bool flags (bombingRunActive, missileChoosingTarget, victory, lastShotDown, …) so
//  impossible combinations cannot exist.
//

import Foundation

enum SetupStep: CaseIterable, Equatable {
    case placeHeadquarter
    case placeMissile1
    case placeMissile2
    case placeBomber
    case placeCoastguard

    var unit: Unit {
        switch self {
        case .placeHeadquarter: return .headquarters
        case .placeMissile1, .placeMissile2: return .missile
        case .placeBomber: return .bomber
        case .placeCoastguard: return .coastguard
        }
    }

    var next: SetupStep? {
        switch self {
        case .placeHeadquarter: return .placeMissile1
        case .placeMissile1: return .placeMissile2
        case .placeMissile2: return .placeBomber
        case .placeBomber: return .placeCoastguard
        case .placeCoastguard: return nil
        }
    }

    var instruction: String {
        switch self {
        case .placeHeadquarter: return "Place headquarter"
        case .placeMissile1: return "Place missile 1"
        case .placeMissile2: return "Place missile 2"
        case .placeBomber: return "Place bomber"
        case .placeCoastguard: return "Place coastguard"
        }
    }

    /// Allowed placement rows for this step.
    /// Player pieces (HQ, missiles, bomber) belong only on southern grass—never on the
    /// opponent's northern turf. Coastguard uses the dedicated water row south of no-man's-land.
    func isValidPlacement(_ row: Int) -> Bool {
        switch self {
        case .placeHeadquarter, .placeMissile1, .placeMissile2, .placeBomber:
            return Zones.isSouthGrass(row)
        case .placeCoastguard:
            return row == Zones.coastguardPlayerRow
        }
    }
}

enum PlayState: Equatable {
    /// Idle, no banner, ready for a new attack or grenade strike.
    case idle
    /// Idle banner shows the most recent shoot-down message; cleared by the next attack.
    /// `attacker` identifies whose weapon got shot down so the banner can pick the
    /// correct phrasing (your bomber vs enemy bomber).
    case shotDown(Weapon, attacker: Side)
    case choosingBombTarget(source: GridPosition)
    case bombingDrops(source: GridPosition, target: GridPosition, dropsApplied: Int)
    case choosingMissileTarget(source: GridPosition)
}

enum Phase: Equatable {
    case welcome
    case setup(SetupStep)
    case play(PlayState)
    /// Terminal: the player hit the opponent's HQ. Only `.newGame` exits this state.
    case victory
    /// Terminal: the opponent hit the player's HQ. Only `.newGame` exits this state.
    case defeat
}

extension Phase {
    /// True for `.play`, `.victory` and `.defeat` — visually treated as "in-game"
    /// (board renders strikes, hides enemy art, etc.) even when the end-game modal is up.
    var isInGame: Bool {
        switch self {
        case .play, .victory, .defeat: return true
        case .welcome, .setup: return false
        }
    }

    /// While the player is choosing a bombing or missile target, this returns the
    /// southern launcher tile so the board can highlight it without an extra branch.
    var targetingSource: GridPosition? {
        switch self {
        case .play(.choosingBombTarget(let src)): return src
        case .play(.choosingMissileTarget(let src)): return src
        default: return nil
        }
    }
}
