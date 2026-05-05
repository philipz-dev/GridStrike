//
//  Action.swift
//  GridStrike Watch App
//
//  All gameplay intents. The reducer is exhaustive over (Phase, Action).
//

import Foundation

enum Action: Equatable {
    case dismissWelcome
    case tap(GridPosition)
    /// Internal — the store schedules this 1 s after the previous bomb drop.
    case advanceBombDrop
    /// Internal — fires once `cooldownDuration` after an attack fully resolves
    /// (excluding HQ kills, which jump straight to victory/defeat). Lifts the
    /// post-attack pause and flips `currentTurn` so the other side can play.
    case completeTurn
    /// Internal — fires after the camera has finished scrolling to the AI's
    /// chosen target, so the impact (overlays + haptics) lands once the player
    /// is actually looking at the right place. Reads the queued
    /// `pendingOpponentImpact` from state and applies it.
    case applyOpponentImpact
    case acknowledgeDestructionAlert
    case newGame
}
