//
//  OpponentPolicy.swift
//  HQStrike Watch App
//
//  Pluggable strategy for whatever drives the opponent's turn — currently a
//  random AI used to validate the turn flow; later a heuristic AI; eventually a
//  multipeer bridge that just forwards remote `Action`s.
//

import Foundation

protocol OpponentPolicy {
    /// Returns the next `Action` the opponent wants to perform given the current
    /// state, or `nil` if there's nothing to do (which should not normally happen
    /// while it's the opponent's turn).
    mutating func nextAction(given state: GameState) -> Action?
}
