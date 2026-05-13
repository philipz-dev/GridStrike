//
//  SideEffect.swift
//  HQStrike Watch App
//
//  Reducer-emitted effects interpreted by the GameStore. Keeps the engine pure and
//  free of WatchKit/Foundation timers.
//

import Foundation
import WatchKit

enum HapticType: Equatable {
    case notification

    var watchHaptic: WKHapticType {
        switch self {
        case .notification: return .notification
        }
    }
}

enum SideEffect: Equatable {
    case haptic(HapticType)
    case scheduleAdvanceBombDrop(afterSeconds: Double)
    /// Reducer signals that the opponent should make its next move after the given
    /// delay. The store interprets this by asking its `OpponentPolicy` for the next
    /// `Action` and dispatching it.
    case scheduleOpponentTurn(afterSeconds: Double)
    /// Lift the post-attack cooldown after a short pause so the player can absorb
    /// the just-rendered impact before the camera scrolls and the other side plays.
    case scheduleCompleteTurn(afterSeconds: Double)
    /// Wait for the impact-scroll animation to finish, then dispatch
    /// `Action.applyOpponentImpact` so overlays + haptics fire only once the
    /// camera is parked over the target tile.
    case scheduleApplyOpponentImpact(afterSeconds: Double)
}
