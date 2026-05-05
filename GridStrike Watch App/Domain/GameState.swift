//
//  GameState.swift
//  GridStrike Watch App
//
//  Single source of truth for the whole game. All UI is derived from this struct.
//  Strike/overlay maps are split per side so the symmetric AI turn (phase 3) can
//  write to its own half without touching the player-attacks-opponent path.
//

import Foundation

/// Where on the screen the scrolled-to view should land. The reducer expresses
/// intent in domain terms (`.center` to centre the tile vertically, `.bottom`
/// to pin it to the viewport's bottom edge — matching the initial-load camera);
/// `BoardView` translates this into SwiftUI's `UnitPoint`.
enum ScrollAnchor: Equatable {
    case center
    case bottom
}

/// Records what the AI has just selected to attack but hasn't yet committed to
/// the board. The reducer parks this on `GameState` while the camera scrolls
/// to the target; `Action.applyOpponentImpact` then reads it back, applies the
/// overlays / haptics, and clears the slot.
enum PendingOpponentImpact: Equatable {
    /// Opponent grenade tap on the player's grass / coastguard row.
    case grenade(target: GridPosition)
    /// Opponent bomber's first drop. Subsequent drops use the existing
    /// `bombingDrops` phase + `advanceBombDrop` ticks.
    case bomber(source: GridPosition, target: GridPosition)
    /// Opponent missile X-pattern centred on `anchor`.
    case missile(source: GridPosition, anchor: GridPosition)
}

/// One queued destruction notification — pairs the side that just attacked
/// with the units that attack destroyed, so the modal can phrase the sentence
/// from the right perspective ("Enemy missile destroyed!" vs. "Your missile is
/// destroyed!"). Kept separate from `GameState` so views and snapshots can
/// pass it around as a single value.
struct DestructionAlert: Equatable {
    let attacker: Side
    let units: [Unit]
}

/// One-shot scroll request emitted by the reducer. The `token` is a monotonic
/// counter so two consecutive requests for the *same* anchor still register as
/// a state change for SwiftUI's `onChange` and re-trigger the scroll animation.
///
/// `id` matches the `.id(...)` modifier on the target view inside `BoardView`.
/// Most anchors are tile rows (`"row-N"`), but special seams between two rows
/// (e.g. `Zones.coastguardDefenseSeamID(defender:)`) are also valid and centre
/// a row-boundary at the viewport's vertical centre via `anchor: .center`.
struct ScrollRequest: Equatable {
    let id: String
    let token: Int
    let anchor: ScrollAnchor
}

struct GameState: Equatable {
    var phase: Phase

    /// Whose attack is currently being resolved. Player-initiated taps are only
    /// honoured when this equals `.player`; the opponent-driven AI/peer turn flips
    /// it back to `.player` once its attack fully resolves.
    var currentTurn: Side

    var board: Board

    /// Deep copy of `board` the moment `.play(.idle)` begins (after enemy spawn).
    /// The post-game frozen map uses this so destroyed units still appear where they
    /// were placed at round start — same as seeing the grid when the bout began.
    var boardAtPlayStart: Board?

    /// Grenade strikes against each side. `grenadeStrikes[.opponent]` holds the
    /// player's grenade taps on rows 0…5; `grenadeStrikes[.player]` holds the
    /// opponent's grenade taps on rows 8…13.
    var grenadeStrikes: PerSide<[GridPosition: ExplosionKind]>

    /// Bomber drop overlays per defender side.
    var bombingOverlays: PerSide<[GridPosition: ExplosionKind]>

    /// Missile 2x2 overlays per defender side.
    var missileOverlays: PerSide<[GridPosition: ExplosionKind]>

    /// Plane-in-water wreckage when an attacker's bomber is shot down. Indexed by
    /// the attacker so we know which water row to render it on.
    var planeInWater: PerSide<GridPosition?>

    /// Missile-in-water wreckage when an attacker's missile is shot down.
    var missileInWater: PerSide<GridPosition?>

    /// FIFO queue of destruction alerts, one entry **per resolved attack**.
    /// Each entry knows the attacker side (so the modal text can switch
    /// between "Enemy …" and "Your …" framing) and lists every unit
    /// destroyed by that single attack so the UI can show one consolidated
    /// modal ("2 enemy missiles destroyed!" / "Your headquarters, bomber and
    /// missile are destroyed!") rather than spamming a modal per cell. Bomb
    /// sequences accumulate into `inFlightBombDestructions` across drops 1–3,
    /// then push a single entry when the salvo finalises.
    var pendingDestructionAlerts: [DestructionAlert]

    /// Accumulator for the units destroyed by the in-flight bomber. Filled by
    /// `applyBombDrop`, drained into `pendingDestructionAlerts` when the
    /// 3-drop sequence finishes. Reset at the start of each new bombing run.
    var inFlightBombDestructions: [Unit]

    /// Opponent attack waiting for the impact-scroll animation to finish before
    /// its overlays / haptics are applied. While set, the board ignores taps
    /// and no further AI actions are scheduled — `Action.applyOpponentImpact`
    /// reads and clears this field once the camera has parked.
    var pendingOpponentImpact: PendingOpponentImpact?

    /// Terminal phase queued for after the post-attack cooldown lifts. Set when
    /// either side's attack lands on the opposing HQ; the reducer keeps `phase`
    /// at `.play(.idle)` so the board (with explosions + orange outlines) keeps
    /// rendering during the 1 s pause, then `Action.completeTurn` swaps `phase`
    /// to this value before the destruction alert + victory/defeat overlay show.
    var pendingEndGamePhase: Phase?

    /// Cells outlined in orange to highlight the most recent attack/defence event.
    /// Used in three scenarios:
    /// 1. The **opponent's** attack landed on the player — these are the impact cells
    ///    (set on grenade impact; replaced at the first bomb drop and appended each
    ///    subsequent drop; replaced wholesale by a missile salvo).
    /// 2. The **player's coastguard** intercepted an AI plane / missile — these are
    ///    the player CG cell (row 8) and the enemy wreck cell (row 7).
    /// 3. The **enemy coastguard** intercepted a player-launched plane / missile —
    ///    these are the enemy CG cell (row 5) and the player wreck cell (row 6).
    /// Cleared when the player launches a non-intercepted attack of their own.
    var lastTurnHighlight: [GridPosition]

    /// True from the moment an attack fully resolves until `Action.completeTurn`
    /// fires (default 1 s later). Locks the board and hides the banner so the
    /// player can absorb the impact before the camera scrolls.
    var isInPostAttackCooldown: Bool

    /// One-shot scroll request — set by the reducer, observed by the BoardView.
    /// Use `requestScroll(to:)` to mutate so the token always advances.
    var scrollRequest: ScrollRequest?

    static func newGame() -> GameState {
        GameState(
            phase: .welcome,
            currentTurn: .player,
            board: .empty,
            boardAtPlayStart: nil,
            grenadeStrikes: PerSide(both: [:]),
            bombingOverlays: PerSide(both: [:]),
            missileOverlays: PerSide(both: [:]),
            planeInWater: PerSide(both: nil),
            missileInWater: PerSide(both: nil),
            pendingDestructionAlerts: [],
            inFlightBombDestructions: [],
            pendingOpponentImpact: nil,
            pendingEndGamePhase: nil,
            lastTurnHighlight: [],
            isInPostAttackCooldown: false,
            scrollRequest: nil
        )
    }

    /// Emit a fresh scroll request to a specific tile row. Defaults to centring
    /// the row in the viewport; pass `.bottom` to pin the row at the viewport's
    /// bottom edge (handy for the last few rows where centring would clip).
    mutating func requestScroll(to row: Int, anchor: ScrollAnchor = .center) {
        requestScroll(toID: "row-\(row)", anchor: anchor)
    }

    /// Emit a fresh scroll request to a custom anchor id (rows or special seams).
    /// The token always advances so identical-id requests still re-trigger
    /// `onChange` in `BoardView`.
    mutating func requestScroll(toID id: String, anchor: ScrollAnchor = .center) {
        let nextToken = (scrollRequest?.token ?? 0) &+ 1
        scrollRequest = ScrollRequest(id: id, token: nextToken, anchor: anchor)
    }
}

// MARK: - UIMode (single exhaustive switch over what the screen is showing)

/// What the user is seeing right now. Combines `phase` + alert queue + end-game into
/// one enum so views and the reducer can use a single exhaustive switch instead of
/// chained bool checks (`if !queue.isEmpty …`, `if victory …`, `if phase == .play …`).
enum UIMode: Equatable {
    case welcome
    case setup(SetupStep)
    case play(PlayState)
    /// One destruction modal per resolved attack; carries the attacker side
    /// plus every unit the attack destroyed so the overlay can render a
    /// single perspective-aware message.
    case destructionAlert(DestructionAlert)
    case victory
    case defeat
}

extension GameState {
    /// True while we're either in the post-attack 1 s cooldown or mid bomb-drop
    /// sequence — both are "active impact" windows where any pending destruction
    /// alert must be held back so the player can see the explosion / orange
    /// outline before the modal interrupts.
    var shouldDeferDestructionAlert: Bool {
        if isInPostAttackCooldown { return true }
        if case .play(.bombingDrops) = phase { return true }
        return false
    }

    var mode: UIMode {
        if !shouldDeferDestructionAlert, let alert = pendingDestructionAlerts.first {
            return .destructionAlert(alert)
        }
        switch phase {
        case .welcome: return .welcome
        case .setup(let step): return .setup(step)
        case .play(let play): return .play(play)
        case .victory: return .victory
        case .defeat: return .defeat
        }
    }

    /// Convenience derived from `mode`. The grid does not respond to taps in any
    /// modal state. Replaces the previous `victory || !queue.isEmpty` pair.
    var isModalActive: Bool {
        switch mode {
        case .destructionAlert, .victory, .defeat: return true
        case .welcome, .setup, .play: return false
        }
    }

    /// True iff the human player can interact with the board right now: in-game,
    /// no modal, no post-attack cooldown, no AI strike mid-flight (i.e. the
    /// camera scrolling toward the AI's next impact), and it's the player's turn.
    var acceptsPlayerInput: Bool {
        guard !isModalActive else { return false }
        guard !isInPostAttackCooldown else { return false }
        guard pendingOpponentImpact == nil else { return false }
        guard case .play = phase else { return false }
        return currentTurn == .player
    }

    /// True once the player has actually launched at least one bomb / missile /
    /// grenade — derived from any record of a player-initiated strike. Used by
    /// the banner to hide the "Start attack!" hint after the first strike.
    var hasPlayerAttacked: Bool {
        !grenadeStrikes[.opponent].isEmpty
            || !bombingOverlays[.opponent].isEmpty
            || !missileOverlays[.opponent].isEmpty
            || planeInWater[.player] != nil
            || missileInWater[.player] != nil
    }
}
