//
//  RandomOpponent.swift
//  GridStrike Watch App
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
        case .bombingDrops:
            return nil      // wait for the scheduled advance-bomb-drop tick
        }
    }

    // MARK: - First tap of the turn

    private func pickWeaponLaunch(state: GameState) -> Action? {
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
                candidates.append(GridPosition(row, col))
            }
        }
        return candidates.randomElement().map { .tap($0) }
    }

    private func pickMissileTarget(state: GameState) -> Action? {
        var candidates: [GridPosition] = []
        for row in Zones.missileTargetRows(attacker: .opponent) {
            for col in Zones.missileTargetColumns {
                candidates.append(GridPosition(row, col))
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
                if state.grenadeStrikes[.player][p] == nil {
                    result.append(p)
                }
            }
        }
        return result
    }
}
