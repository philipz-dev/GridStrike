//
//  BoardSnapshot.swift
//  HQStrike Watch App
//
//  One-pass projection from GameState → render data for every tile + banner + modal.
//  Driven entirely by `phase` / `mode`; no bool flags. Strike/overlay reads are
//  side-aware so the same renderer covers both halves of the board.
//

import Foundation

struct BoardSnapshot: Equatable {
    let tiles: [GridPosition: TileRenderModel]
    let banner: BannerKind
    let modal: Modal?

    enum Modal: Equatable {
        /// Carries the attacker side and every unit destroyed by the most
        /// recently resolved attack so the overlay can render one aggregated
        /// perspective-aware message ("Enemy …" vs "Your …").
        case destructionAlert(DestructionAlert)
        case victory
        case defeat
    }

    static func compute(_ state: GameState) -> BoardSnapshot {
        var tiles: [GridPosition: TileRenderModel] = [:]
        tiles.reserveCapacity(Zones.rowCount * Zones.columnCount)
        for row in Zones.allRows {
            for col in Zones.allColumns {
                let pos = GridPosition(row, col)
                tiles[pos] = makeTile(at: pos, state: state)
            }
        }

        let modal: Modal? = {
            switch state.mode {
            case .destructionAlert(let alert): return .destructionAlert(alert)
            case .victory: return .victory
            case .defeat: return .defeat
            case .welcome, .setup, .setupConfirm, .play: return nil
            }
        }()

        return BoardSnapshot(tiles: tiles, banner: state.banner, modal: modal)
    }

    // MARK: - Per-tile decision

    private static func makeTile(at pos: GridPosition, state: GameState) -> TileRenderModel {
        let mark = state.board.unit(at: pos)
        let hideEnemyArt = hidesEnemyUnitArt(at: pos, state: state)
        // A coastguard cell whose cruiser has been destroyed renders the wreck
        // artwork directly — no explosion overlay, no enemy-art hiding (we
        // want the player to see exactly where the CG used to sit).
        let isSunkCG = isSunkCoastguardCell(at: pos, state: state)

        let missileSalvoGhost: Unit? = {
            guard state.missileSalvoPulseHitCells.contains(pos) else { return nil }
            guard let side = Zones.side(forRow: pos.row) else { return nil }
            guard state.missileOverlays[side][pos] == .hit else { return nil }
            return state.missileSalvoGhostUnits[pos]
        }()

        let background: TileBackground = {
            if isSunkCG { return .coastguardSunk }
            if let ghost = missileSalvoGhost {
                return .unit(ghost)
            }
            if hideEnemyArt {
                return Zones.isWater(pos.row) ? .water : .grass
            }
            if let mark = mark {
                return .unit(mark)
            }
            return Zones.isWater(pos.row) ? .water : .grass
        }()

        let bomberRotation: Double = {
            let showsBomber = (mark == .bomber) || (missileSalvoGhost == .bomber)
            guard showsBomber, !hideEnemyArt else { return 0 }
            return state.board.bomberRotations[pos] ?? 0
        }()

        let dim = ghostMode(at: pos, state: state)
        let offCoastguard = isPlaceCoastguardOffFocus(at: pos, state: state)

        let strikeOverlay: ExplosionKind? = {
            // Sunk-CG cells drop their strike overlay so the wreck art reads
            // cleanly without an explosion stacked on top.
            guard !isSunkCG else { return nil }
            guard state.phase.isInGame else { return nil }
            // Each tile only ever carries strikes against its own side. Mid-water
            // rows (6, 7) belong to no side and stay clean.
            guard let side = Zones.side(forRow: pos.row) else { return nil }
            // Grenade strikes are valid on the defender's grass + their coastguard row.
            // For .opponent that's rows 0–5; for .player rows 8–13.
            let grenadeAttacker = side.opposite
            guard Zones.isGrenadeTarget(pos, attacker: grenadeAttacker) else { return nil }
            return state.grenadeStrikes[side][pos]
        }()

        let dropOverlay: ExplosionKind? = {
            // Same suppression as `strikeOverlay`: a destroyed CG shows the
            // wreck art instead of a missile/bomb explosion.
            guard !isSunkCG else { return nil }
            guard state.phase.isInGame else { return nil }
            guard let side = Zones.side(forRow: pos.row) else { return nil }
            return state.bombingOverlays[side][pos] ?? state.missileOverlays[side][pos]
        }()

        let wreckInfo: (kind: WaterWreck, attacker: Side)? = {
            guard state.phase.isInGame else { return nil }
            // Plane/missile-in-water sits on the *attacker*'s wreck row, indexed by
            // the attacker side.
            for attacker in Side.allCases {
                if state.planeInWater[attacker] == pos { return (.plane, attacker) }
                if state.missileInWater[attacker] == pos { return (.missile, attacker) }
            }
            return nil
        }()
        let wreck = wreckInfo?.kind
        let wreckRotation: Double = {
            switch wreckInfo?.attacker {
            case .player:   return 45  // your downed bomber/missile (existing tilt)
            case .opponent: return 135 // enemy wreck — 90° + extra 45° clockwise
            case .none:     return 0
            }
        }()
        let isLastTurnHighlight =
            state.phase.isInGame && state.lastTurnHighlight.contains(pos)

        // The selection border only applies to player-driven targeting; during the
        // opponent's turn the AI's hidden launcher should not flash a border.
        let isSelected = state.currentTurn == .player && state.phase.targetingSource == pos

        let border: TileBorder = {
            if isSelected { return .selected }
            if dim != .none { return .dim }
            return .plain
        }()

        let isDisabled = isTileDisabled(
            at: pos,
            state: state,
            mark: mark,
            isSelected: isSelected
        )

        let missileHitPulseToken: UInt32? = {
            guard let side = Zones.side(forRow: pos.row) else { return nil }
            guard state.missileSalvoPulseHitCells.contains(pos) else { return nil }
            guard state.missileOverlays[side][pos] == .hit else { return nil }
            return state.missileImpactPulseGeneration
        }()

        return TileRenderModel(
            position: pos,
            background: background,
            bomberRotationDegrees: bomberRotation,
            dim: dim,
            offCoastguardFocusRow: offCoastguard,
            northStrikeOverlay: strikeOverlay,
            dropOverlay: dropOverlay,
            dropOverlayScale: 1,
            missileHitPulseToken: missileHitPulseToken,
            waterWreck: wreck,
            wreckRotationDegrees: wreckRotation,
            border: border,
            isLastTurnHighlight: isLastTurnHighlight,
            isDisabled: isDisabled
        )
    }

    // MARK: - Per-tile helpers

    /// During play (and post-victory while the modal is up), opponent tiles on rows 0–5
    /// hide their unit graphics — strike/bomb logic still runs against `state.board`.
    ///
    /// The opponent coastguard is revealed when:
    /// • the player's missile was shot down in that column (**DEBUG**-independent), or
    /// • **`HQStrikeDebug.showEnemyCoastguardPlacement`** is enabled (**DEBUG** only).
    private static func hidesEnemyUnitArt(at pos: GridPosition, state: GameState) -> Bool {
#if DEBUG
        if HQStrikeDebug.showAllEnemyPiecesOnPlayfield,
           state.phase.isInGame,
           pos.row <= Zones.coastguardEnemyRow {
            return false
        }
#endif
        guard state.phase.isInGame, pos.row <= Zones.coastguardEnemyRow else { return false }
        return !revealsEnemyCoastguard(at: pos, state: state)
    }

    /// True when this tile is the wreck of a destroyed coastguard — i.e. it
    /// sits on a side's coastguard row, that side originally had a coastguard
    /// at this column (per `boardAtPlayStart`), and the live board no longer
    /// has a coastguard for this side. Reads from `boardAtPlayStart` so the
    /// wreck stays anchored to the original column even after the cruiser
    /// mark has been removed from the live board.
    private static func isSunkCoastguardCell(at pos: GridPosition, state: GameState) -> Bool {
        guard state.phase.isInGame else { return false }
        guard let side = Zones.side(forRow: pos.row) else { return false }
        guard pos.row == Zones.coastguardRow(of: side) else { return false }
        guard let original = state.boardAtPlayStart,
              let originalCol = original.coastguardColumn(of: side) else { return false }
        // Cruiser still alive on this side — render the regular CG art (or
        // hide it for the enemy CG until it's revealed). We only swap to the
        // wreck art once the live coastguard is gone.
        guard state.board.coastguardColumn(of: side) == nil else { return false }
        return pos.col == originalCol
    }

    private static func revealsEnemyCoastguard(at pos: GridPosition, state: GameState) -> Bool {
        guard pos.row == Zones.coastguardEnemyRow,
              state.board.unit(at: pos) == .coastguard,
              let cgCol = state.board.coastguardColumn(of: .opponent),
              pos.col == cgCol else {
            return false
        }
        // Any successful interception by the enemy CG (missile *or* bomber) reveals
        // the cruiser so the orange highlight + wreck readout makes sense.
        if state.missileInWater[.player] != nil { return true }
        if state.planeInWater[.player] != nil { return true }
#if DEBUG
        return HQStrikeDebug.showEnemyCoastguardPlacement
#else
        return false
#endif
    }

    private static func isPlaceCoastguardOffFocus(at pos: GridPosition, state: GameState) -> Bool {
        if case .setup(.placeCoastguard) = state.phase {
            return pos.row != Zones.coastguardPlayerRow
        }
        return false
    }

    private static func ghostMode(at pos: GridPosition, state: GameState) -> DimMode {
        // While panning is disabled (`BoardView` `.scrollDisabled`), keep every tile
        // at full brightness — no targeting scrim during opponent turn, post-strike
        // pause, deferred AI impact scroll, or playfield modal.
        if !state.allowsPlayfieldScrolling { return .none }

        // Ghost dim only applies to player-driven targeting; during the opponent's
        // turn the board renders normally (the AI plans behind the scenes).
        let isPlayerTurn = state.currentTurn == .player

        switch state.phase {
        case .play(.choosingBombTarget(let src)) where isPlayerTurn:
            if pos == src { return .none }
            return Zones.bombingTargetRows.contains(pos.row) ? .none : .normal

        case .play(.choosingMissileTarget(let src)) where isPlayerTurn:
            if pos == src { return .none }
            return Zones.isMissileTarget(pos) ? .none : .normal

        case .play, .victory, .defeat, .setupConfirm:
            // setupConfirm renders the player's finished layout at full
            // brightness — the floating confirm/restart buttons are the only
            // affordance, so no tile dimming is needed.
            return .none

        case .setup(.placeCoastguard):
            return pos.row != Zones.coastguardPlayerRow ? .coastguardOffRow : .none

        case .setup(let step):
            if state.board.marks[pos] != nil { return .none }
            return step.isValidPlacement(pos.row) ? .none : .normal

        case .welcome:
            return .none
        }
    }

    private static func isTileDisabled(
        at pos: GridPosition,
        state: GameState,
        mark: Unit?,
        isSelected: Bool
    ) -> Bool {
        if state.isModalActive { return true }
        // Lock every tile while the post-attack pause is held — the reducer would
        // refuse the tap anyway, but disabling here keeps the watch UI consistent
        // with the suppressed banner.
        if state.isInPostAttackCooldown { return true }
        // Same lock while the camera is scrolling toward the AI's queued impact:
        // the reducer ignores taps until `applyOpponentImpact` fires.
        if state.pendingOpponentImpact != nil { return true }

        switch state.phase {
        case .welcome, .victory, .defeat, .setupConfirm:
            // `.setupConfirm` is already covered by the `isModalActive`
            // early-return above; listed here so the switch stays exhaustive.
            return false
        case .setup(let step):
            if mark != nil { return false }
            return !step.isValidPlacement(pos.row)
        case .play(let play):
            // Block all taps during the opponent's turn — the reducer would refuse
            // them anyway, but disabling at the view level keeps the watch UI snappy.
            if state.currentTurn != .player { return true }
            switch play {
            case .choosingMissileTarget:
                return !(Zones.isMissileTarget(pos) || isSelected)
            case .choosingBombTarget:
                return !(Zones.isBombingTarget(pos) || isSelected)
            case .bombingDrops, .missileFlight:
                return true
            case .missileInterceptFlight, .bomberInterceptFlight, .opponentMissileInterceptFlight,
                 .opponentBomberInterceptFlight:
                return true
            case .idle, .shotDown:
                return false
            }
        }
    }
}
