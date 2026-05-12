//
//  EnemySpawner.swift
//  HQStrike Watch App
//
//  Computer opponent setup once the player finishes placing units. The coastguard is
//  now grenade-killable, so the AI mixes two recipes — biased 70/30 toward Fortress
//  so the player most often sees the coastguard parked in front of HQ + bomber,
//  while Mirage still keeps the layout from becoming a fixed pattern:
//
//  • Fortress — HQ + bomber + 1 missile cluster behind the coastguard column. While
//    the coastguard lives, every bomber/missile attack on that column is intercepted;
//    with a corner coastguard column HQ is fully missile-proof until the coastguard
//    is destroyed.
//
//  • Mirage — HQ sits in a column far away from the coastguard; the coastguard's
//    column is stuffed with the bomber and both missiles as decoys. The player still
//    sees attacks on that column intercepted, but a shoot-down no longer reveals
//    HQ's column. To verify HQ isn't there the player has to grenade-scan the column,
//    burning extra taps on three decoys.
//
//  Both recipes:
//    • bias the coastguard column toward a corner (0 or 4) for maximum intercept reach,
//    • keep all AI units pairwise at Chebyshev distance ≥ 2 so a single 2x2 missile
//      cannot wipe two AI units at once,
//    • avoid putting two non-coastguard units in the same column unless the
//      coastguard defends it.
//
//  Each placement uses a tiered constraint pick (strict → soft → "anything") so the
//  spawner still finds a valid spot if the player has occupied cells on rows 0–4
//  during setup.
//

import Foundation

enum EnemySpawner {
    static func apply<R: RandomNumberGenerator>(board: inout Board, rng: inout R) {
        guard !board.didApplyEnemySpawn else { return }

        var available: Set<GridPosition> = []
        for row in Zones.northGrass {
            for col in Zones.allColumns {
                let p = GridPosition(row, col)
                if board.marks[p] == nil { available.insert(p) }
            }
        }
        guard available.count >= 4 else { return }
        board.didApplyEnemySpawn = true

        // 1) Coastguard column — corner bias for full intercept reach.
        let coastCol = pickCoastguardColumn(rng: &rng)

        // 2) HQ — 70% same column as coastguard ("fortress"), 30% far away ("mirage").
        //    The fortress bias keeps the coastguard standing in front of HQ + bomber
        //    most of the time (what the player intuitively expects), while the 30%
        //    mirage rate prevents the placement from becoming a recognisable pattern.
        //    The chosen mode degrades gracefully via the fallback chain when blocked.
        let preferFortress = Double.random(in: 0..<1, using: &rng) < 0.7
        let hqConstraints: [(GridPosition) -> Bool] = preferFortress
            ? [
                { p in p.col == coastCol },
                { p in abs(p.col - coastCol) >= 2 },
                { p in p.col != coastCol },
                { _ in true },
            ]
            : [
                { p in abs(p.col - coastCol) >= 2 },
                { p in p.col != coastCol },
                { p in p.col == coastCol },
                { _ in true },
            ]
        guard let hq = pickPosition(from: available, constraints: hqConstraints, rng: &rng) else { return }
        board.marks[hq] = .headquarters
        available.remove(hq)
        let isFortress = (hq.col == coastCol)

        // 3) Bomber — always in the coastguard column. In fortress: row distance ≥ 2
        //    from HQ. In mirage: Chebyshev ≥ 2 from HQ (auto-satisfied when |hq.col - coastCol| ≥ 2).
        let bomberConstraints: [(GridPosition) -> Bool] = isFortress
            ? [
                { p in p.col == coastCol && abs(p.row - hq.row) >= 2 },
                { p in chebyshev(p, hq) >= 2 },
                { p in chebyshev(p, hq) >= 1 },
            ]
            : [
                { p in p.col == coastCol && chebyshev(p, hq) >= 2 },
                { p in chebyshev(p, hq) >= 2 },
                { p in chebyshev(p, hq) >= 1 },
            ]
        guard let bomber = pickPosition(from: available, constraints: bomberConstraints, rng: &rng) else { return }
        board.marks[bomber] = .bomber
        board.bomberRotations[bomber] = 180
        available.remove(bomber)

        // 4) Missile 1 —
        //    Fortress: spread to an unused column (so no single bomber column wipes two AI units).
        //    Mirage:  prefer coastguard column (decoy alongside bomber), Chebyshev ≥ 2 from bomber.
        let placedSoFar: [GridPosition] = [hq, bomber]
        let missile1Constraints: [(GridPosition) -> Bool]
        if isFortress {
            let usedCols: Set<Int> = [hq.col, bomber.col]
            missile1Constraints = [
                { p in placedSoFar.allSatisfy { chebyshev(p, $0) >= 2 } && !usedCols.contains(p.col) },
                { p in placedSoFar.allSatisfy { chebyshev(p, $0) >= 2 } },
                { p in placedSoFar.allSatisfy { chebyshev(p, $0) >= 1 } },
            ]
        } else {
            missile1Constraints = [
                { p in p.col == coastCol && placedSoFar.allSatisfy { chebyshev(p, $0) >= 2 } },
                { p in placedSoFar.allSatisfy { chebyshev(p, $0) >= 2 } && p.col != hq.col },
                { p in placedSoFar.allSatisfy { chebyshev(p, $0) >= 2 } },
                { p in placedSoFar.allSatisfy { chebyshev(p, $0) >= 1 } },
            ]
        }
        guard let missile1 = pickPosition(from: available, constraints: missile1Constraints, rng: &rng) else { return }
        board.marks[missile1] = .missile
        available.remove(missile1)

        // 5) Missile 2 —
        //    Fortress: another unused column.
        //    Mirage:  again prefer coastguard column so all three decoys cluster behind it.
        let placedAfterM1: [GridPosition] = [hq, bomber, missile1]
        let missile2Constraints: [(GridPosition) -> Bool]
        if isFortress {
            let usedCols: Set<Int> = [hq.col, bomber.col, missile1.col]
            missile2Constraints = [
                { p in placedAfterM1.allSatisfy { chebyshev(p, $0) >= 2 } && !usedCols.contains(p.col) },
                { p in placedAfterM1.allSatisfy { chebyshev(p, $0) >= 2 } },
                { p in placedAfterM1.allSatisfy { chebyshev(p, $0) >= 1 } },
            ]
        } else {
            missile2Constraints = [
                { p in p.col == coastCol && placedAfterM1.allSatisfy { chebyshev(p, $0) >= 2 } },
                { p in p.col != hq.col && placedAfterM1.allSatisfy { chebyshev(p, $0) >= 2 } },
                { p in placedAfterM1.allSatisfy { chebyshev(p, $0) >= 2 } },
                { p in placedAfterM1.allSatisfy { chebyshev(p, $0) >= 1 } },
            ]
        }
        guard let missile2 = pickPosition(from: available, constraints: missile2Constraints, rng: &rng) else { return }
        board.marks[missile2] = .missile

        // 6) Coastguard at (5, coastCol).
        let coastPos = GridPosition(Zones.coastguardEnemyRow, coastCol)
        if board.marks[coastPos] == nil {
            board.marks[coastPos] = .coastguard
        }
    }

    // MARK: - Helpers

    private static func chebyshev(_ a: GridPosition, _ b: GridPosition) -> Int {
        max(abs(a.row - b.row), abs(a.col - b.col))
    }

    /// Try each predicate in order; pick a random match from the first non-empty filter. The ultimate
    /// fallback is any available cell so the spawner never deadlocks on a heavily-blocked board.
    private static func pickPosition<R: RandomNumberGenerator>(
        from available: Set<GridPosition>,
        constraints: [(GridPosition) -> Bool],
        rng: inout R
    ) -> GridPosition? {
        for predicate in constraints {
            let candidates = available.filter(predicate)
            if let pick = candidates.randomElement(using: &rng) { return pick }
        }
        return available.randomElement(using: &rng)
    }

    /// 70% corner column (0 or 4), 30% interior. A corner coastguard intercepts every 2x2 missile
    /// that touches that column (c == 0 directly, or c == 3 via the rightmost-edge rule), which
    /// in turn fully missile-proofs HQ when HQ shares the column.
    private static func pickCoastguardColumn<R: RandomNumberGenerator>(rng: inout R) -> Int {
        let cols = Array(Zones.allColumns)
        guard let firstCol = cols.first, let lastCol = cols.last else { return 0 }
        let corners = [firstCol, lastCol]
        let interior = cols.filter { !corners.contains($0) }

        let pickCorner = Double.random(in: 0..<1, using: &rng) < 0.7 || interior.isEmpty
        let pool = pickCorner ? corners : interior
        return pool.randomElement(using: &rng) ?? firstCol
    }
}
