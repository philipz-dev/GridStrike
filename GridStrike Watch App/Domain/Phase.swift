//
//  Phase.swift
//  HQStrike Watch App
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
        case .placeMissile1: return "Place first missile"
        case .placeMissile2: return "Place second missile"
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
    /// Scripted coastguard intercept (player missile vs enemy CG) — matches `Demo_Coastguard`
    /// visuals; commit happens on `Action.finalizePlayerMissileIntercept`.
    case missileInterceptFlight(source: GridPosition, anchor: GridPosition)
    /// Same coastguard intercept trailer as the missile path, but flying `bomber_transparent`;
    /// commit on `Action.finalizePlayerBomberIntercept`.
    case bomberInterceptFlight(source: GridPosition, anchor: GridPosition)
    /// Opponent missile vs player coastguard — mirrored scroll + southbound missile;
    /// commit on `Action.finalizeOpponentMissileIntercept`.
    case opponentMissileInterceptFlight(source: GridPosition, anchor: GridPosition)
    /// Opponent bomber vs player coastguard — same mirrored trailer with `bomber_transparent`;
    /// commit on `Action.finalizeOpponentBomberIntercept`.
    case opponentBomberInterceptFlight(source: GridPosition, anchor: GridPosition)
    case choosingBombTarget(source: GridPosition)
    case bombingDrops(source: GridPosition, target: GridPosition, dropsApplied: Int)
    /// Missile in flight — same scroll + sprite path as bomber (mirrored for the opponent);
    /// X-pattern commits in one explosion on `commitMissileFlightStrike` when the missile
    /// crosses the anchor row.
    case missileFlight(source: GridPosition, anchor: GridPosition, attacker: Side)
    case choosingMissileTarget(source: GridPosition)
}

enum Phase: Equatable {
    case welcome
    case setup(SetupStep)
    /// Player has just placed their last unit and is being asked to confirm the
    /// layout. Two buttons (red ✗ / green ✓) sit on top of the live board so
    /// the player can either restart placement from scratch or commit to the
    /// current setup, at which point the AI's units are spawned and play begins.
    case setupConfirm
    case play(PlayState)
    /// Terminal: the player hit the opponent's HQ. Only `.newGame` exits this state.
    case victory
    /// Terminal: the opponent hit the player's HQ. Only `.newGame` exits this state.
    case defeat
}

extension Phase {
    /// True for `.play`, `.victory` and `.defeat` — visually treated as "in-game"
    /// (board renders strikes, hides enemy art, etc.) even when the end-game modal is up.
    /// `.setupConfirm` is *not* in-game: the AI hasn't been spawned yet, so we
    /// keep the board rendered like late setup (player units shown, north grass
    /// empty) instead of switching to the play-time fog mask.
    var isInGame: Bool {
        switch self {
        case .play, .victory, .defeat: return true
        case .welcome, .setup, .setupConfirm: return false
        }
    }

    /// While the player is choosing a bombing or missile target, this returns the
    /// southern launcher tile so the board can highlight it without an extra branch.
    var targetingSource: GridPosition? {
        switch self {
        case .play(.choosingBombTarget(let src)): return src
        case .play(.choosingMissileTarget(let src)): return src
        case .play(.missileInterceptFlight(let src, _)),
             .play(.bomberInterceptFlight(let src, _)),
             .play(.opponentMissileInterceptFlight(let src, _)),
             .play(.opponentBomberInterceptFlight(let src, _)):
            return src
        default: return nil
        }
    }
}
