//
//  SmartOpponent.swift
//  GridStrike Watch App
//
//  Heuristic opponent that plays like a curious-but-cautious player. It uses ONLY
//  information it has earned in-game (its own grenade history on the player half
//  and any wreckage from intercepted strikes); it never peeks at the player's
//  `board.marks`. The strategy in three beats:
//
//  1. SCOUT — until the player's coastguard column is known (or the coastguard is
//     destroyed), the AI mostly fires grenades at row 8. Each grenade either kills
//     the CG outright (a `.hit`) or rules out one column (a `.miss`).
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
    /// Missile anchor columns where the full 5-cell X-pattern lands inside the
    /// player's half. Anchoring on column 0 or 4 only delivers 3 cells (the two
    /// off-board diagonals are dropped), so the AI avoids the corners except as
    /// a deliberate, low-probability variation or when no wide column is safe.
    private static let wideMissileColumns: ClosedRange<Int> = 1...3
    /// Probability of intentionally anchoring a missile in a corner column even
    /// when a wide column is available — keeps the AI from being completely
    /// predictable about the corners while still treating them as exceptions.
    private static let cornerMissileLapseProbability: Double = 0.05

    init() {}

    mutating func nextAction(given state: GameState) -> Action? {
        guard state.currentTurn == .opponent else { return nil }
        guard !state.isModalActive else { return nil }
        guard case .play(let play) = state.phase else { return nil }

        let belief = computeBelief(state: state)

        switch play {
        case .idle, .shotDown:
            return pickWeaponLaunch(state: state, belief: belief)
        case .choosingBombTarget:
            return pickBomberTarget(state: state, belief: belief)
        case .choosingMissileTarget:
            return pickMissileTarget(state: state, belief: belief)
        case .bombingDrops:
            return nil      // wait for the scheduled advance-bomb-drop tick
        }
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
        let cgResolved = belief.cgConfirmedDestroyed || belief.cgKnownColumn != nil
        let safeCols = belief.safeCols
        let hasSafeLaunch = canLaunch && hasViableLaunch(bombers: bombers, missiles: missiles, safeCols: safeCols)

        // SCOUT phase — CG status unresolved and there are still row-8 cells to probe.
        if !cgResolved, !belief.unprobedRow8Cols.isEmpty {
            // ~30% of the time, take a "safe" launch first if the AI has already
            // confirmed at least one clear column — otherwise probe.
            if hasSafeLaunch, Double.random(in: 0..<1) < 0.30 {
                if let action = launchAction(bombers: bombers, missiles: missiles, safeCols: safeCols) {
                    return action
                }
            }
            if let action = probeAction(belief: belief) { return action }
            if let action = launchAction(bombers: bombers, missiles: missiles, safeCols: safeCols) { return action }
            return huntAction(state: state, belief: belief)
        }

        // PRESS phase — CG resolved (destroyed or column pinned down) or row 8
        // already fully probed. Mostly launch into safe columns.
        let launchCols = safeCols.isEmpty ? Array(Zones.allColumns) : safeCols
        if canLaunch, Double.random(in: 0..<1) < 0.85 {
            if let action = launchAction(bombers: bombers, missiles: missiles, safeCols: launchCols) {
                return action
            }
        }
        if let action = huntAction(state: state, belief: belief) { return action }
        return launchAction(bombers: bombers, missiles: missiles, safeCols: launchCols)
    }

    /// Grenade tap on a random unprobed row-8 column.
    private func probeAction(belief: Belief) -> Action? {
        guard let col = belief.unprobedRow8Cols.randomElement() else { return nil }
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
        let corners = safeCols.filter { Zones.missileTargetColumns.contains($0) }
        if !corners.isEmpty, Double.random(in: 0..<1) < Self.cornerMissileLapseProbability {
            return true
        }
        return false
    }

    /// Random un-grenaded cell on the player's grass (rows 9–13). Biased toward
    /// safe columns: those are where the player's HQ / launchers are likeliest
    /// to be parked since they cluster off the coastguard column.
    private func huntAction(state: GameState, belief: Belief) -> Action? {
        let strikes = state.grenadeStrikes[.player]
        let safeColSet = Set(belief.safeCols)

        var preferred: [GridPosition] = []
        var fallback: [GridPosition] = []
        for row in Zones.southGrass {
            for col in Zones.allColumns {
                let p = GridPosition(row, col)
                if strikes[p] != nil { continue }
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

    private func pickBomberTarget(state: GameState, belief: Belief) -> Action? {
        let safeCols = belief.safeCols
        let bombed = Set(state.bombingOverlays[.player].keys)

        // Best: a safe column with at least one un-bombed cell.
        if let pick = bombingTargets(cols: safeCols, exclude: bombed).randomElement() {
            return .tap(pick)
        }
        // Acceptable: a safe column even if every cell was already bombed.
        if let pick = bombingTargets(cols: safeCols, exclude: []).randomElement() {
            return .tap(pick)
        }
        // Last resort: any legal target so the reducer never deadlocks.
        return bombingTargets(cols: Array(Zones.allColumns), exclude: []).randomElement().map { .tap($0) }
    }

    private func pickMissileTarget(state: GameState, belief: Belief) -> Action? {
        let safeWide = belief.safeCols.filter { Self.wideMissileColumns.contains($0) }
        let safeCornerCols = belief.safeCols.filter {
            Zones.missileTargetColumns.contains($0) && !Self.wideMissileColumns.contains($0)
        }
        let struck = Set(state.missileOverlays[.player].keys)

        // Best: a wide (5-cell) safe column.
        if let pick = missileTargets(cols: safeWide, exclude: struck).randomElement() {
            return .tap(pick)
        }
        if let pick = missileTargets(cols: safeWide, exclude: []).randomElement() {
            return .tap(pick)
        }
        // Exception: settle for a corner column only when wide cols are unavailable.
        if let pick = missileTargets(cols: safeCornerCols, exclude: struck).randomElement() {
            return .tap(pick)
        }
        if let pick = missileTargets(cols: safeCornerCols, exclude: []).randomElement() {
            return .tap(pick)
        }
        // Last-resort fallback: any legal anchor regardless of safety, still
        // preferring wide columns over corners.
        let allWide = Array(Self.wideMissileColumns)
        if let pick = missileTargets(cols: allWide, exclude: []).randomElement() {
            return .tap(pick)
        }
        let anyCols = Array(Zones.missileTargetColumns)
        return missileTargets(cols: anyCols, exclude: []).randomElement().map { .tap($0) }
    }

    private func bombingTargets(cols: [Int], exclude: Set<GridPosition>) -> [GridPosition] {
        var result: [GridPosition] = []
        // Use the safe (all-3-drops-land) range — the AI never benefits from
        // walking drops off the back of the board even though it's now legal.
        for row in Zones.safeBombingTargetRows(attacker: .opponent) {
            for col in cols {
                let p = GridPosition(row, col)
                if !exclude.contains(p) { result.append(p) }
            }
        }
        return result
    }

    private func missileTargets(cols: [Int], exclude: Set<GridPosition>) -> [GridPosition] {
        var result: [GridPosition] = []
        for row in Zones.missileTargetRows(attacker: .opponent) {
            for col in cols {
                let p = GridPosition(row, col)
                if !exclude.contains(p) { result.append(p) }
            }
        }
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
