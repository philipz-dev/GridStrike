//
//  RandomOpponent.swift
//  HQStrike Watch App
//
//  Phase-3a opponent: picks fully random — but always *valid* — taps. Used to
//  exercise the symmetric reducer and turn flow before any heuristics ship.
//
//  Uses the system RNG via the no-argument `randomElement()` / `Int.random(in:)`
//  family. A seedable variant can be added later for unit-tested AI vs AI runs.
//

import Foundation

struct RandomOpponent: OpponentPolicy {
    init() {}

    mutating func nextAction(given state: GameState) -> Action? {
        guard state.currentTurn == .opponent else { return nil }
        guard !state.isModalActive else { return nil }
        guard case .play(let play) = state.phase else { return nil }

        switch play {
        case .idle, .shotDown:
            return pickWeaponLaunch(state: state)
        case .choosingBombTarget:
            return pickBomberTarget(state: state)
        case .choosingMissileTarget:
            return pickMissileTarget(state: state)
        case .bombingDrops, .missileFlight:
            return nil      // wait for the scheduled advance-bomb-drop tick
        case .missileInterceptFlight, .bomberInterceptFlight, .opponentMissileInterceptFlight,
             .opponentBomberInterceptFlight:
            return nil
        }
    }

    // MARK: - First tap of the turn

    private func pickWeaponLaunch(state: GameState) -> Action? {
        if HQStrikeOpponentDebugStrikeFilter.prefersBomberAndMissileFirst {
            if let pos = ownUnits(state: state, of: .bomber).randomElement() { return .tap(pos) }
            if let pos = ownUnits(state: state, of: .missile).randomElement() { return .tap(pos) }
            if let pos = grenadeCandidates(state: state).randomElement() { return .tap(pos) }
            return nil
        }

        var options: [Action] = []

        // Tap one of our remaining bombers to start a column attack.
        if let pos = ownUnits(state: state, of: .bomber).randomElement() {
            options.append(.tap(pos))
        }

        // Tap one of our remaining missiles to start a 2x2 attack.
        if let pos = ownUnits(state: state, of: .missile).randomElement() {
            options.append(.tap(pos))
        }

        // Tap any unstruck cell on the player's grenade-target zone (rows 8–13).
        if let pos = grenadeCandidates(state: state).randomElement() {
            options.append(.tap(pos))
        }

        return options.randomElement()
    }

    private func pickBomberTarget(state: GameState) -> Action? {
        var candidates: [GridPosition] = []
        // Match SmartOpponent — even the random AI shouldn't deliberately waste
        // drops off the back of the board (rows 12, 13 for the opponent).
        for row in Zones.safeBombingTargetRows(attacker: .opponent) {
            for col in Zones.allColumns {
                let p = GridPosition(row, col)
                let footprint = Rules.bombingPositions(target: p, attacker: .opponent)
                guard HQStrikeOpponentDebugStrikeFilter.opponentMayStrike(board: state.board, footprint: footprint) else {
                    continue
                }
                candidates.append(p)
            }
        }
        return candidates.randomElement().map { .tap($0) }
    }

    private func pickMissileTarget(state: GameState) -> Action? {
        var candidates: [GridPosition] = []
        for row in Zones.missileTargetRows(attacker: .opponent) {
            for col in Zones.missileTargetColumns {
                let p = GridPosition(row, col)
                if Zones.isWastedOpponentMissileAnchor(p) { continue }
                let footprint = Rules.missilePositions(anchor: p, attacker: .opponent)
                guard HQStrikeOpponentDebugStrikeFilter.opponentMayStrike(board: state.board, footprint: footprint) else {
                    continue
                }
                candidates.append(p)
            }
        }
        return candidates.randomElement().map { .tap($0) }
    }

    // MARK: - Helpers

    private func ownUnits(state: GameState, of unit: Unit) -> [GridPosition] {
        var result: [GridPosition] = []
        for row in Zones.grassRows(of: .opponent) {
            for col in Zones.allColumns {
                let p = GridPosition(row, col)
                if state.board.unit(at: p) == unit { result.append(p) }
            }
        }
        return result
    }

    private func grenadeCandidates(state: GameState) -> [GridPosition] {
        var result: [GridPosition] = []
        for row in Zones.grenadeTargetRows(attacker: .opponent) {
            for col in Zones.allColumns {
                let p = GridPosition(row, col)
                guard state.grenadeStrikes[.player][p] == nil else { continue }
                guard HQStrikeOpponentDebugStrikeFilter.opponentMayStrike(board: state.board, footprint: [p]) else {
                    continue
                }
                result.append(p)
            }
        }
        return result
    }
}
