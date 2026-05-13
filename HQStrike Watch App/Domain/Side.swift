//
//  Side.swift
//  HQStrike Watch App
//
//  Marks which half of the board owns a tile or initiates an attack. The map is
//  symmetric: rows 0–5 belong to `.opponent`, rows 8–13 to `.player`, with two
//  empty water rows (6, 7) in between. Almost every spatial helper in `Zones` and
//  every attack-direction helper in `Rules` is parameterised on `Side`.
//

import Foundation

enum Side: Hashable, CaseIterable {
    case player
    case opponent

    /// The defender of attacks launched by this side.
    var opposite: Side {
        switch self {
        case .player: return .opponent
        case .opponent: return .player
        }
    }
}

/// Compact value-type holder for "one thing per side". Both halves are always
/// present, so callers never have to deal with optional-of-optional lookups.
struct PerSide<T: Equatable>: Equatable {
    var player: T
    var opponent: T

    init(player: T, opponent: T) {
        self.player = player
        self.opponent = opponent
    }

    /// Both sides initialised to the same value (handy for empty dicts/optionals).
    init(both: T) {
        self.player = both
        self.opponent = both
    }

    subscript(side: Side) -> T {
        get {
            switch side {
            case .player: return player
            case .opponent: return opponent
            }
        }
        set {
            switch side {
            case .player: player = newValue
            case .opponent: opponent = newValue
            }
        }
    }
}
