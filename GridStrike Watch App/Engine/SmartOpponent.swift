//
//  SmartOpponent.swift
//  HQStrike Watch App
//
//  Heuristic opponent that plays like a curious-but-cautious player. It uses ONLY
//  information it has earned in-game (its own grenade history on the player half
//  and any wreckage from intercepted strikes); it never peeks at the player's
//  `board.marks`. The strategy in three beats:
//
//  1. SCOUT — until the player's coastguard column is known (or the coastguard is
//     destroyed), the AI probes row 8. Each grenade either kills the CG (`.hit`)
//     or rules out a column (`.miss`). Once at least one column has missed — i.e.
//     we know that column cannot host the coastguard — we **prefer missile/bomber**
//     launches down those safe columns instead of endlessly grenading row 8.
//  2. PRESS — once the CG's status is resolved, the AI mostly launches missiles
//     and bombers, preferring columns it has confirmed are safe so it can't be
//     intercepted.
//  3. HUNT — between launches the AI occasionally grenades the player's grass
//     (rows 9–13), biased toward safe columns where units are likelier to sit.
//
//  Every choice ends in `randomElement()` over a filtered candidate set, so the
//  player never sees a left-to-right or top-to-bottom sweep — even on repeat play.
//

import Foundation

struct SmartOpponent: OpponentPolicy {
    /// Missile anchors in columns **1…3** keep all five X-pattern cells on-board;
    /// columns **0** and **4** drop two side diagonals, and **rows 9 and 13** waste
    /// pattern cells into water / off-board — `missileTargets` filters those anchors
    /// out so the AI never wastes salvo cells (see `Zones.isWastedOpponentMissileAnchor`).
    private static let wideMissileColumns: ClosedRange<Int> = 1...3
    /// Probability of intentionally anchoring a missile in a corner column even
    /// when a wide column is available — keeps the AI from being completely
    /// predictable about the corners while still treating them as exceptions.
    private static let cornerMissileLapseProbability: Double = 0.05

    /// Most recent row-8 grenade column the AI has played. Read by the next
    /// bomber / missile target picker so the follow-up launch reuses the
    /// column we just probed: a HIT cleared the coastguard there, a MISS
    /// confirmed the column is interception-free either way. Cleared once
    /// the value is consumed by a target pick so the bias only nudges the
    /// next launch, not every launch forever.
    private var preferredLaunchCol: Int?

    init() {}

    mutating func nextAction(given state: GameState) -> Action? {
        guard state.currentTurn == .opponent else { return nil }
        guard !state.isModalActive else { return nil }
        guard case .play(let play) = state.phase else { return nil }

        let belief = computeBelief(state: state)

        let result: Action?
        switch play {
        case .idle, .shotDown:
            result = pickWeaponLaunch(state: state, belief: belief)
        case .choosingBombTarget:
            result = pickBomberTarget(state: state, belief: belief)
        case .choosingMissileTarget:
            result = pickMissileTarget(state: state, belief: belief)
        case .bombingDrops, .missileFlight:
            result = nil       // wait for the scheduled advance-bomb-drop tick
        case .missileInterceptFlight, .bomberInterceptFlight, .opponentMissileInterceptFlight,
             .opponentBomberInterceptFlight:
            result = nil
        }

        // Save the column whenever we just emitted a row-8 grenade probe so
        // the follow-up launch on a later turn can target the same column.
        // Launcher taps (north grass, rows 0–4) and target taps (south grass,
        // rows 9–13) never satisfy this row check, so it only fires for
        // probes.
        if let action = result,
           case .tap(let pos) = action,
           pos.row == Zones.coastguardPlayerRow {
            preferredLaunchCol = pos.col
        }

        return result
    }

    // MARK: - Belief

    /// Everything the AI thinks it knows about the player's coastguard, derived
    /// purely from its own observations.
    private struct Belief {
        /// A row-8 grenade landed on the coastguard — it's gone, every column safe.
        let cgConfirmedDestroyed: Bool
        /// CG is alive but we know which column it sits in (from process of
        /// elimination after 4 row-8 misses, or from wreckage of a prior shoot-down).
        let cgKnownColumn: Int?
        /// Row-8 columns the AI has already grenaded (hit or miss).
        let probedRow8Cols: Set<Int>
        /// Row-8 columns the AI has not yet grenaded.
        let unprobedRow8Cols: [Int]

        /// Columns the AI considers safe to attack (no risk of CG interception).
        ///   - CG destroyed → all 5 columns.
        ///   - CG column known → the other 4 columns.
        ///   - Otherwise → only columns we already missed on row 8 (confirmed clear).
        var safeCols: [Int] {
            if cgConfirmedDestroyed { return Array(Zones.allColumns) }
            if let col = cgKnownColumn {
                return Zones.allColumns.filter { $0 != col }
            }
            // We only know a column is safe if we already grenade-missed it.
            return probedRow8Cols.sorted()
        }
    }

    private func computeBelief(state: GameState) -> Belief {
        let strikes = state.grenadeStrikes[.player]
        let missileOverlays = state.missileOverlays[.player]
        let bombingOverlays = state.bombingOverlays[.player]
        let row = Zones.coastguardPlayerRow

        var cgDestroyed = false
        var probed: Set<Int> = []
        var missCount = 0

        for col in Zones.allColumns {
            let cell = GridPosition(row, col)
            // Grenade probe outcome.
            if let kind = strikes[cell] {
                probed.insert(col)
                switch kind {
                case .hit: cgDestroyed = true
                case .miss: missCount += 1
                }
            }
            // A missile diagonal or bomber drop on row 8 with a `.hit` overlay can
            // only have hit the coastguard — that row is otherwise pure water for
            // the player side. Treat those as proof the cruiser is gone, even
            // though the AI never grenade-probed that column itself.
            if missileOverlays[cell] == .hit || bombingOverlays[cell] == .hit {
                cgDestroyed = true
            }
        }

        // Process-of-elimination column. Only meaningful while CG is alive.
        var inferredCol: Int? = nil
        if !cgDestroyed, missCount == Zones.allColumns.count - 1 {
            inferredCol = Zones.allColumns.first { !probed.contains($0) }
        }

        // Wreckage from a prior intercepted attack pinpoints the CG column directly:
        // both bomber and missile interception require the launcher's target/anchor
        // column to equal the defender CG column, and the wreck inherits that column.
        var wreckCol: Int? = nil
        if !cgDestroyed {
            if let p = state.planeInWater[.opponent] { wreckCol = p.col }
            if let p = state.missileInWater[.opponent] { wreckCol = p.col }
        }

        let unprobed = Zones.allColumns.filter { !probed.contains($0) }

        return Belief(
            cgConfirmedDestroyed: cgDestroyed,
            cgKnownColumn: wreckCol ?? inferredCol,
            probedRow8Cols: probed,
            unprobedRow8Cols: unprobed
        )
    }

    // MARK: - First tap of the turn

    private func pickWeaponLaunch(state: GameState, belief: Belief) -> Action? {
        let bombers = ownUnits(state: state, of: .bomber)
        let missiles = ownUnits(state: state, of: .missile)
        let canLaunch = !bombers.isEmpty || !missiles.isEmpty

        // No launchers left → the player's coastguard can't intercept anything
        // anymore, so probing row 8 only burns turns. Skip the SCOUT/PRESS
        // launch tracks entirely and hunt the HQ in the player's grass instead.
        if !canLaunch {
            return huntAction(state: state, belief: belief)
        }

        // DEBUG: exhaust bomber/missile launcher taps (with relaxed column safety) before
        // row-8 probes or grass hunts.
        if HQStrikeOpponentDebugStrikeFilter.prefersBomberAndMissileFirst {
            let safeCols = belief.safeCols
            if let action = launchAction(bombers: bombers, missiles: missiles, safeCols: safeCols) {
                return action
            }
            let relaxed = Array(Zones.allColumns)
            if let action = launchAction(bombers: bombers, missiles: missiles, safeCols: relaxed) {
                return action
            }
        }

        let cgResolved = belief.cgConfirmedDestroyed || belief.cgKnownColumn != nil
        let safeCols = belief.safeCols
        let hasSafeLaunch = hasViableLaunch(bombers: bombers, missiles: missiles, safeCols: safeCols)

        // SCOUT phase — CG status unresolved and there are still row-8 cells to probe.
        if !cgResolved, !belief.unprobedRow8Cols.isEmpty {
            // After at least one row-8 **miss**, `safeCols` lists columns where the CG
            // cannot sit — use those for bomber/missile instead of always grenading.
            // Before any miss we mostly probe; once we have safe columns we strongly
            // prefer launching (still occasionally probing unfinished row-8 cells).
            let knowSafeColumnFromMiss = !belief.safeCols.isEmpty
            let launchFirstProbability = knowSafeColumnFromMiss ? 0.86 : 0.28
            if hasSafeLaunch, Double.random(in: 0..<1) < launchFirstProbability {
                if let action = launchAction(bombers: bombers, missiles: missiles, safeCols: safeCols) {
                    return action
                }
            }
            if let action = probeAction(state: state, belief: belief) { return action }
            if let action = launchAction(bombers: bombers, missiles: missiles, safeCols: safeCols) { return action }
            return huntAction(state: state, belief: belief)
        }

        // PRESS phase — CG resolved (destroyed or column pinned down) or row 8
        // already fully probed. Mostly launch into safe columns.
        let launchCols = safeCols.isEmpty ? Array(Zones.allColumns) : safeCols
        if Double.random(in: 0..<1) < 0.85 {
            if let action = launchAction(bombers: bombers, missiles: missiles, safeCols: launchCols) {
                return action
            }
        }
        if let action = huntAction(state: state, belief: belief) { return action }
        return launchAction(bombers: bombers, missiles: missiles, safeCols: launchCols)
    }

    /// Grenade tap on a random unprobed row-8 column (skips columns that still hold a
    /// player coastguard when `HQStrikeDebug.opponentNeverAttacksPlayerCoastguardTiles`).
    private func probeAction(state: GameState, belief: Belief) -> Action? {
        let cols = belief.unprobedRow8Cols.filter { col in
            let p = GridPosition(Zones.coastguardPlayerRow, col)
            return HQStrikeOpponentDebugStrikeFilter.opponentMayStrike(board: state.board, footprint: [p])
        }
        guard let col = cols.randomElement() else { return nil }
        return .tap(GridPosition(Zones.coastguardPlayerRow, col))
    }

    /// Random tap on a launcher tile, but only of a type that has at least one
    /// safe target. The returned tap transitions the reducer into
    /// `.choosingBombTarget` / `.choosingMissileTarget`; the actual target is
    /// chosen on the next AI step using the same belief.
    ///
    /// Missiles count as launchable as long as a wide safe column (1…3) exists,
    /// because anchoring in a corner column wastes two of the X-pattern's cells.
    /// We do allow a launch with only corner cols safe, but only as a rare
    /// `cornerMissileLapseProbability` lapse; otherwise the AI falls back to a
    /// bomber or grenade.
    private func launchAction(
        bombers: [GridPosition],
        missiles: [GridPosition],
        safeCols: [Int]
    ) -> Action? {
        var pool: [GridPosition] = []
        if !bombers.isEmpty, !safeCols.isEmpty {
            pool.append(contentsOf: bombers)
        }
        if !missiles.isEmpty, missilesAreLaunchable(safeCols: safeCols) {
            pool.append(contentsOf: missiles)
        }
        return pool.randomElement().map { .tap($0) }
    }

    private func hasViableLaunch(bombers: [GridPosition], missiles: [GridPosition], safeCols: [Int]) -> Bool {
        if !bombers.isEmpty, !safeCols.isEmpty { return true }
        if !missiles.isEmpty, missilesAreLaunchable(safeCols: safeCols) { return true }
        return false
    }

    /// True if any wide (5-cell) safe column exists, or — exceptionally — when
    /// only corner cols are safe and a small RNG lapse fires. Treats wide vs
    /// corner asymmetrically so the AI doesn't keep blowing missiles for 3-cell
    /// hits when better options exist.
    private func missilesAreLaunchable(safeCols: [Int]) -> Bool {
        if safeCols.contains(where: { Self.wideMissileColumns.contains($0) }) { return true }
        let corners = safeCols.filter { Zones.missileCornerColumns.contains($0) }
        if !corners.isEmpty, Double.random(in: 0..<1) < Self.cornerMissileLapseProbability {
            return true
        }
        return false
    }

    /// Random un-attacked cell on the player's grass (rows 9–13). Biased toward
    /// safe columns: those are where the player's HQ / launchers are likeliest
    /// to be parked since they cluster off the coastguard column.
    ///
    /// "Un-attacked" here means no grenade strike, bombing overlay, or missile
    /// overlay has ever landed on the cell, regardless of hit/miss. Re-targeting
    /// any of those wastes the grenade — it can't reveal new info or do new
    /// damage on a cell whose contents we've already resolved.
    private func huntAction(state: GameState, belief: Belief) -> Action? {
        let attacked = attackedCellsAgainstPlayer(state: state)
        let safeColSet = Set(belief.safeCols)

        var preferred: [GridPosition] = []
        var fallback: [GridPosition] = []
        for row in Zones.southGrass {
            for col in Zones.allColumns {
                let p = GridPosition(row, col)
                if attacked.contains(p) { continue }
                if !HQStrikeOpponentDebugStrikeFilter.opponentMayStrike(board: state.board, footprint: [p]) {
                    continue
                }
                if !safeColSet.isEmpty, safeColSet.contains(col) {
                    preferred.append(p)
                } else {
                    fallback.append(p)
                }
            }
        }
        if let p = preferred.randomElement() { return .tap(p) }
        return fallback.randomElement().map { .tap($0) }
    }

    // MARK: - Targeting

    private mutating func pickBomberTarget(state: GameState, belief: Belief) -> Action? {
        let safeCols = belief.safeCols
        let attacked = attackedCellsAgainstPlayer(state: state)

        // Follow up the most recent row-8 grenade with a strike on the same
        // column. Bombers deliver all three drops as long as the anchor row
        // sits inside `safeBombingTargetRows`, so honouring the preferred col
        // here never costs the salvo any cells.
        if let preferred = preferredLaunchCol, safeCols.contains(preferred) {
            preferredLaunchCol = nil
            // Best on the preferred col: anchor and entire 3-drop column avoid
            // every previously attacked cell.
            if let pick = bombingTargets(board: state.board, cols: [preferred], exclude: attacked, avoidFootprintHits: true).randomElement() {
                return .tap(pick)
            }
            // Acceptable: anchor itself isn't on a previously attacked cell.
            if let pick = bombingTargets(board: state.board, cols: [preferred], exclude: attacked).randomElement() {
                return .tap(pick)
            }
            // Tolerable: use the preferred col even with full overlap so we
            // honour the row-8 follow-up rule; better an overlap on the right
            // column than walking off it entirely.
            if let pick = bombingTargets(board: state.board, cols: [preferred], exclude: []).randomElement() {
                return .tap(pick)
            }
            // Preferred col yielded nothing — fall through to the general
            // safety heuristics below.
        } else {
            preferredLaunchCol = nil
        }

        // Best: a safe col where the anchor and every drop avoid prior attacks.
        if let pick = bombingTargets(board: state.board, cols: safeCols, exclude: attacked, avoidFootprintHits: true).randomElement() {
            return .tap(pick)
        }
        // Acceptable: a safe col with at least an un-attacked anchor.
        if let pick = bombingTargets(board: state.board, cols: safeCols, exclude: attacked).randomElement() {
            return .tap(pick)
        }
        // Tolerable: a safe col even with full overlap.
        if let pick = bombingTargets(board: state.board, cols: safeCols, exclude: []).randomElement() {
            return .tap(pick)
        }
        // Last resort: any legal target so the reducer never deadlocks.
        return bombingTargets(board: state.board, cols: Array(Zones.allColumns), exclude: []).randomElement().map { .tap($0) }
    }

    private mutating func pickMissileTarget(state: GameState, belief: Belief) -> Action? {
        let attacked = attackedCellsAgainstPlayer(state: state)

        // Same row-8 follow-up rule for missiles when the preferred column still yields
        // a valid anchor — skip south-corner anchors that waste pattern cells off-board.
        if let preferred = preferredLaunchCol, belief.safeCols.contains(preferred) {
            preferredLaunchCol = nil
            if let pick = missileTargets(board: state.board, cols: [preferred], exclude: attacked, avoidFootprintHits: true)
                .randomElement() {
                return .tap(pick)
            }
            if let pick = missileTargets(board: state.board, cols: [preferred], exclude: attacked).randomElement() {
                return .tap(pick)
            }
            if let pick = missileTargets(board: state.board, cols: [preferred], exclude: []).randomElement() {
                return .tap(pick)
            }
        } else {
            preferredLaunchCol = nil
        }

        let safeWide = belief.safeCols.filter { Self.wideMissileColumns.contains($0) }
        let safeCornerCols = belief.safeCols.filter { Zones.missileCornerColumns.contains($0) }

        // Best: wide (5-cell) safe col, X-pattern entirely on un-attacked cells.
        if let pick = missileTargets(board: state.board, cols: safeWide, exclude: attacked, avoidFootprintHits: true).randomElement() {
            return .tap(pick)
        }
        // Acceptable: wide safe col with un-attacked anchor.
        if let pick = missileTargets(board: state.board, cols: safeWide, exclude: attacked).randomElement() {
            return .tap(pick)
        }
        // Tolerable: wide safe col, any anchor.
        if let pick = missileTargets(board: state.board, cols: safeWide, exclude: []).randomElement() {
            return .tap(pick)
        }
        // Settle for corner cols only when wide cols are unavailable, keeping
        // the same overlap-avoidance ladder.
        if let pick = missileTargets(board: state.board, cols: safeCornerCols, exclude: attacked, avoidFootprintHits: true).randomElement() {
            return .tap(pick)
        }
        if let pick = missileTargets(board: state.board, cols: safeCornerCols, exclude: attacked).randomElement() {
            return .tap(pick)
        }
        if let pick = missileTargets(board: state.board, cols: safeCornerCols, exclude: []).randomElement() {
            return .tap(pick)
        }
        // Last-resort fallback: any legal anchor regardless of safety, still
        // preferring wide columns over corners.
        let allWide = Array(Self.wideMissileColumns)
        if let pick = missileTargets(board: state.board, cols: allWide, exclude: []).randomElement() {
            return .tap(pick)
        }
        let anyCols = Array(Zones.missileTargetColumns)
        return missileTargets(board: state.board, cols: anyCols, exclude: []).randomElement().map { .tap($0) }
    }

    /// Bomber anchor candidates. `exclude` removes the anchor cells themselves
    /// from the pool; `avoidFootprintHits` additionally drops any anchor whose
    /// 3-drop column intersects the exclude set, so the salvo never lands a
    /// drop on a cell that has already been resolved.
    private func bombingTargets(
        board: Board,
        cols: [Int],
        exclude: Set<GridPosition>,
        avoidFootprintHits: Bool = false
    ) -> [GridPosition] {
        var result: [GridPosition] = []
        // Use the safe (all-3-drops-land) range — the AI never benefits from
        // walking drops off the back of the board even though it's now legal.
        for row in Zones.safeBombingTargetRows(attacker: .opponent) {
            for col in cols {
                let p = GridPosition(row, col)
                if exclude.contains(p) { continue }
                let footprint = Rules.bombingPositions(target: p, attacker: .opponent)
                if !HQStrikeOpponentDebugStrikeFilter.opponentMayStrike(board: board, footprint: footprint) {
                    continue
                }
                if avoidFootprintHits {
                    if footprint.contains(where: { exclude.contains($0) }) { continue }
                }
                result.append(p)
            }
        }
        return result
    }

    /// Missile anchor candidates. Same `exclude` / `avoidFootprintHits` contract
    /// as `bombingTargets`, but the footprint check uses the X-pattern instead
    /// of the 3-drop column.
    private func missileTargets(
        board: Board,
        cols: [Int],
        exclude: Set<GridPosition>,
        avoidFootprintHits: Bool = false
    ) -> [GridPosition] {
        var result: [GridPosition] = []
        for row in Zones.missileTargetRows(attacker: .opponent) {
            for col in cols {
                let p = GridPosition(row, col)
                if Zones.isWastedOpponentMissileAnchor(p) { continue }
                if exclude.contains(p) { continue }
                let footprint = Rules.missilePositions(anchor: p, attacker: .opponent)
                if !HQStrikeOpponentDebugStrikeFilter.opponentMayStrike(board: board, footprint: footprint) {
                    continue
                }
                if avoidFootprintHits {
                    if footprint.contains(where: { exclude.contains($0) }) { continue }
                }
                result.append(p)
            }
        }
        return result
    }

    /// Every cell on the player's half that the AI has already resolved with
    /// any kind of strike — grenade, bomb, or missile — regardless of whether
    /// it landed as a hit or a miss. Used to keep the AI from re-targeting
    /// tiles whose contents are already known.
    private func attackedCellsAgainstPlayer(state: GameState) -> Set<GridPosition> {
        var result: Set<GridPosition> = []
        result.formUnion(state.grenadeStrikes[.player].keys)
        result.formUnion(state.bombingOverlays[.player].keys)
        result.formUnion(state.missileOverlays[.player].keys)
        return result
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
}
