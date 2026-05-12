//
//  GameStore.swift
//  HQStrike Watch App
//
//  Observable host for the game. The store holds the current `GameState`, applies
//  reducer outputs, and interprets side effects (haptics, bomb-drop timer and the
//  opponent-turn schedule).
//

import Foundation
import Observation
import SwiftUI
import WatchKit

@MainActor
@Observable
final class GameStore {
    private(set) var state: GameState
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var opponent: any OpponentPolicy

    init(
        initial: GameState = .newGame(),
        opponent: any OpponentPolicy = SmartOpponent()
    ) {
        self.state = initial
        self.opponent = opponent
    }

    func send(_ action: Action) {
        let (next, effects) = GameReducer.reduce(state: state, action: action, rng: &rng)
        state = next
        for effect in effects { run(effect) }
    }

    // MARK: - Effect interpreter

    private func run(_ effect: SideEffect) {
        switch effect {
        case .haptic(let kind):
            WKInterfaceDevice.current().play(kind.watchHaptic)
        case .scheduleAdvanceBombDrop(let delay):
            schedule(after: delay) { [weak self] in
                self?.send(.advanceBombDrop)
            }
        case .scheduleOpponentTurn(let delay):
            schedule(after: delay) { [weak self] in
                self?.runOpponentStep()
            }
        case .scheduleCompleteTurn(let delay):
            schedule(after: delay) { [weak self] in
                self?.send(.completeTurn)
            }
        case .scheduleApplyOpponentImpact(let delay):
            schedule(after: delay) { [weak self] in
                self?.send(.applyOpponentImpact)
            }
        }
    }

    private func runOpponentStep() {
        // The reducer schedules opponent turns whenever the AI is up; if state has
        // since shifted (e.g. game ended, modal opened during the delay), bail out
        // gracefully — the next reducer pass will reschedule if still relevant.
        guard let action = opponent.nextAction(given: state) else { return }
        send(action)
    }

    private func schedule(after delay: Double, _ block: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            block()
        }
    }
}
