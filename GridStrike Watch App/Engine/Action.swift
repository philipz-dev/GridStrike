//
//  Action.swift
//  HQStrike Watch App
//
//  All gameplay intents. The reducer is exhaustive over (Phase, Action).
//

import Foundation

enum Action: Equatable {
    case dismissWelcome
    case tap(GridPosition)
    /// Internal — the store schedules this 1 s after the previous bomb drop.
    case advanceBombDrop
    /// Internal — after fly-over timing, applies the full missile X-pattern at once.
    case commitMissileFlightStrike
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
    /// Player has reviewed the setup-confirm screen and wants to wipe the board
    /// and start placing units again from the headquarters step.
    case restartSetup
    /// Player has reviewed the setup-confirm screen and wants to lock in the
    /// current layout. Spawns the AI's units and transitions to play.
    case confirmSetup
    case newGame
    /// Reset to welcome after the post-game opponent map; opens the tactical menu (skip splash).
    case finishPostGameMapReview
    /// Internal — `StartView` clears `welcomePresentStartMenu` after applying it.
    case clearWelcomeStartMenuRequest
    /// Internal — after `Demo_Coastguard`-aligned intercept visuals on `BoardView`,
    /// commits wreck / shot-down / cooldown state for the player missile intercept.
    case finalizePlayerMissileIntercept
    /// Internal — same trailer as missile intercept, for a player bomber shot down
    /// by the enemy coastguard (`planeInWater`, launcher removal, `.shotDown`).
    case finalizePlayerBomberIntercept
    /// Internal — mirrored coastguard trailer when the player’s coastguard downs an AI missile.
    case finalizeOpponentMissileIntercept
    /// Internal — mirrored coastguard trailer when the player’s coastguard downs an AI bomber.
    case finalizeOpponentBomberIntercept
}
