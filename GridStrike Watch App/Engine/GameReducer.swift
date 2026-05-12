//
//  GameReducer.swift
//  GridStrike Watch App
//
//  Pure reducer driven by the typed `UIMode` enum and the explicit `Phase` machine.
//  Every attack is parameterised on `state.currentTurn`, so the same code path
//  handles player and opponent offensives. After each attack fully resolves we
//  hold the result on screen for `cooldownDuration` (board locked, banner muted),
//  then `Action.completeTurn` flips the turn and — if the opponent is up next —
//  schedules its move.
//

import Foundation

enum GameReducer {
    /// Pause held after every non-HQ-killing attack so the player can absorb the
    /// just-rendered impact before the camera scrolls and the other side plays.
    private static let cooldownDuration: Double = 1.0
    /// Extra hold added to `cooldownDuration` after a coastguard interception
    /// so the player has more time to read the "shot down" banner before the
    /// turn flips. Stacks on top of the regular cooldown — total interception
    /// pause is `cooldownDuration + shotDownExtraCooldown` seconds.
    private static let shotDownExtraCooldown: Double = 2.0
    /// Delay before the opponent makes its first move after the post-attack
    /// cooldown lifts. Generous enough for the auto-scroll animation to finish
    /// and the "Thinking…" banner to register before the first impact lands.
    private static let opponentPostAttackDelay: Double = 1.2
    /// Slightly longer pause after a shoot-down so the player can finish reading
    /// the shoot-down banner.
    private static let opponentPostShotDownDelay: Double = 1.5
    /// Delay between sequential opponent taps within the same turn (e.g. bomber
    /// source-tap → target-tap). No scroll change happens here.
    private static let opponentInterTapDelay: Double = 0.5
    /// Time the camera needs to glide to the AI's chosen target before its
    /// overlays / haptics land. A hair longer than `BoardView`'s scroll
    /// animation (0.06 s setup + 0.45 s ease) so the impact only appears once
    /// the tile is actually parked under the player's eyes.
    private static let opponentImpactScrollDuration: Double = 0.55

    static func reduce<R: RandomNumberGenerator>(
        state: GameState,
        action: Action,
        rng: inout R
    ) -> (GameState, [SideEffect]) {
        var s = state
        var effects: [SideEffect] = []

        switch action {

        // MARK: Always-on actions (work even while a modal is up)

        case .newGame:
            return (.newGame(), [])

        case .finishPostGameMapReview:
            var next = GameState.newGame()
            next.welcomePresentStartMenu = true
            return (next, [])

        case .clearWelcomeStartMenuRequest:
            s.welcomePresentStartMenu = false
            return (s, [])

        case .finalizePlayerMissileIntercept:
            if case .play(.missileInterceptFlight(let source, let anchor)) = s.phase {
                commitPlayerMissileIntercept(state: &s, source: source, anchor: anchor, effects: &effects)
            }
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .finalizePlayerBomberIntercept:
            if case .play(.bomberInterceptFlight(let source, let anchor)) = s.phase {
                commitPlayerBomberIntercept(state: &s, source: source, anchor: anchor, effects: &effects)
            }
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .finalizeOpponentMissileIntercept:
            if case .play(.opponentMissileInterceptFlight(let source, let anchor)) = s.phase {
                commitOpponentMissileIntercept(state: &s, source: source, anchor: anchor, effects: &effects)
            }
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .finalizeOpponentBomberIntercept:
            if case .play(.opponentBomberInterceptFlight(let source, let anchor)) = s.phase {
                commitOpponentBomberIntercept(state: &s, source: source, anchor: anchor, effects: &effects)
            }
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .acknowledgeDestructionAlert:
            if !s.pendingDestructionAlerts.isEmpty {
                s.pendingDestructionAlerts.removeFirst()
            }
            // After the last alert, the next opponent step (if any) might have been
            // waiting — re-evaluate the scheduling tail before returning.
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .advanceBombDrop:
            // Internal scheduled action — runs regardless of modal so a HQ-hit during
            // a drop sequence can't strand the remaining drops behind an alert.
            if case .play(.bombingDrops(let src, let target, let n)) = s.phase {
                handleAdvanceBombDrop(
                    state: &s,
                    source: src,
                    target: target,
                    dropsApplied: n,
                    effects: &effects
                )
            }
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .commitMissileFlightStrike:
            if case .play(.missileFlight(let source, let anchor, let attacker)) = s.phase {
                applyMissileSalvo(
                    state: &s,
                    attacker: attacker,
                    source: source,
                    anchor: anchor,
                    effects: &effects
                )
            }
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .completeTurn:
            // Internal — fires `cooldownDuration` after an attack resolves. Lifts
            // the cooldown lock; if the latest attack killed an HQ, swap to the
            // terminal phase here so the destruction alert + victory/defeat
            // overlay only appear AFTER the player has seen the explosion. If
            // not terminal, hand the turn over to the other side.
            if s.isInPostAttackCooldown {
                s.isInPostAttackCooldown = false
                s.missileSalvoPulseHitCells = []
                s.missileSalvoGhostUnits = [:]
                if let endPhase = s.pendingEndGamePhase {
                    s.phase = endPhase
                    s.pendingEndGamePhase = nil
                } else {
                    endTurn(state: &s)
                }
            }
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .applyOpponentImpact:
            // Internal — fires `opponentImpactScrollDuration` after the AI taps
            // its target, i.e. once the camera has finished panning. Reads back
            // the queued impact and commits the overlays / haptics now.
            if let pending = s.pendingOpponentImpact {
                s.pendingOpponentImpact = nil
                resolvePendingOpponentImpact(state: &s, pending: pending, effects: &effects)
            }
            appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
            return (s, effects)

        case .dismissWelcome:
            if case .welcome = s.phase {
                s.phase = .setup(.placeHeadquarter)
            }
            return (s, [])

        case .restartSetup:
            // Player rejected their layout on the confirm screen — wipe every
            // placed unit (and any setup-time scaffolding like the bomber's
            // rotation map) and rewind to the very first placement step.
            if case .setupConfirm = s.phase {
                s.board.marks = [:]
                s.board.bomberRotations = [:]
                s.board.didApplyEnemySpawn = false
                s.phase = .setup(.placeHeadquarter)
                // Bring the camera back to the bottom so HQ placement begins
                // with the same view the welcome → setup transition gives.
                s.requestScroll(to: Zones.rowCount - 1, anchor: .bottom)
            }
            return (s, [])

        case .confirmSetup:
            // Player accepted their layout — spawn the AI's units, snapshot
            // the board for the post-game map, and start the play phase. We
            // mirror the original setup-completion logic from `handleSetupTap`,
            // which used to fire automatically on coastguard placement.
            if case .setupConfirm = s.phase {
                EnemySpawner.apply(board: &s.board, rng: &rng)
#if DEBUG
                if GridStrikeDebug.fillRow8WithPlayerCoastguards {
                    for col in Zones.allColumns {
                        let p = GridPosition(Zones.coastguardPlayerRow, col)
                        s.board.marks[p] = .coastguard
                    }
                }
#endif
                s.boardAtPlayStart = s.board
                s.phase = .play(.idle)
                s.currentTurn = .player
                s.requestScroll(to: Zones.opponentOverviewRow)
            }
            return (s, [])

        // MARK: Tap routing

        case .tap(let pos):
            switch s.mode {
            case .destructionAlert, .victory, .defeat, .setupConfirm:
                return (s, [])  // modal blocks input — setupConfirm uses its own buttons
            case .welcome:
                s.phase = .setup(.placeHeadquarter)
                return (s, [])
            case .setup(let step):
                handleSetupTap(state: &s, step: step, pos: pos)
                return (s, [])
            case .play(let play):
                // Cooldown locks the board between resolution and the turn flip.
                guard !s.isInPostAttackCooldown else { return (s, []) }
                // Likewise hold any taps while we're waiting for the AI's
                // impact-scroll to finish — the queued impact is about to fire.
                guard s.pendingOpponentImpact == nil else { return (s, []) }
                handlePlayTap(state: &s, playState: play, pos: pos, effects: &effects)
                appendOpponentSchedulingIfNeeded(state: s, effects: &effects)
                return (s, effects)
            }
        }
    }

    // MARK: - Setup

    /// Handles a placement tap during the `.setup(...)` phase. After the last
    /// unit lands, we now park in `.setupConfirm` so the player gets a chance
    /// to review and either commit (`Action.confirmSetup`) or restart from
    /// scratch (`Action.restartSetup`). The AI spawn that used to fire here
    /// has moved to the `confirmSetup` branch in `reduce`.
    private static func handleSetupTap(
        state s: inout GameState,
        step: SetupStep,
        pos: GridPosition
    ) {
        guard step.isValidPlacement(pos.row) else { return }
        guard s.board.marks[pos] == nil else { return }

        s.board.marks[pos] = step.unit

        if let next = step.next {
            s.phase = .setup(next)
            if next == .placeCoastguard {
                s.requestScroll(to: Zones.coastguardPlayerRow)
            }
        } else {
            s.phase = .setupConfirm
        }
    }

    // MARK: - Play tap dispatch

    private static func handlePlayTap(
        state s: inout GameState,
        playState: PlayState,
        pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        switch playState {
        case .idle, .shotDown:
            handleIdleTap(state: &s, pos: pos, effects: &effects)
        case .choosingBombTarget(let src):
            // Tapping the highlighted launcher cancels the in-flight selection
            // and returns to idle, so the player can pick a different bomber /
            // missile (or fire a grenade instead) without being trapped on the
            // first tile they tapped.
            if pos == src {
                s.phase = .play(.idle)
                return
            }
            handleConfirmBombTap(state: &s, source: src, pos: pos, effects: &effects)
        case .choosingMissileTarget(let src):
            if pos == src {
                s.phase = .play(.idle)
                return
            }
            handleConfirmMissileTap(state: &s, source: src, pos: pos, effects: &effects)
        case .bombingDrops, .missileFlight:
            // Drops / missile fly-over in flight; ignore taps.
            break
        case .missileInterceptFlight, .bomberInterceptFlight, .opponentMissileInterceptFlight,
             .opponentBomberInterceptFlight:
            break
        }
    }

    // MARK: - Idle / shot-down (attacker = state.currentTurn)

    private static func handleIdleTap(
        state s: inout GameState,
        pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = s.currentTurn
        let mark = s.board.unit(at: pos)
        let attackerGrass = Zones.grassRows(of: attacker)

        // Tap own bomber / missile to start an attack — phase change implicitly clears
        // any `.shotDown` banner.
        if attackerGrass.contains(pos.row), mark == .bomber {
            s.phase = .play(.choosingBombTarget(source: pos))
            return
        }
        if attackerGrass.contains(pos.row), mark == .missile {
            s.phase = .play(.choosingMissileTarget(source: pos))
            return
        }

        // Grenade strike on the defender's grass + coastguard row.
        guard Zones.isGrenadeTarget(pos, attacker: attacker) else { return }
        let defender = attacker.opposite
        guard s.grenadeStrikes[defender][pos] == nil else { return }

        if attacker == .opponent {
            beginDeferredOpponentImpact(
                state: &s,
                impact: .grenade(target: pos),
                target: pos,
                effects: &effects
            )
            return
        }

        applyGrenadeImpact(state: &s, attacker: attacker, target: pos, effects: &effects)
    }

    /// Commits a grenade strike: writes the strike map, optionally clears a
    /// destroyed coastguard from the board, queues destruction alerts, and
    /// starts the post-attack cooldown. Called immediately for player-driven
    /// grenades; called via `Action.applyOpponentImpact` for AI grenades after
    /// the impact-scroll animation finishes.
    private static func applyGrenadeImpact(
        state s: inout GameState,
        attacker: Side,
        target pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let defender = attacker.opposite
        let mark = s.board.unit(at: pos)

        // Drop any `.shotDown` banner now that a real strike is happening.
        s.phase = .play(.idle)

        recordAttackImpact(state: &s, attacker: attacker, cells: [pos])

        let isHit = mark != nil
        s.grenadeStrikes[defender][pos] = isHit ? .hit : .miss
        effects.append(.haptic(.notification))
        if let unit = mark {
            // A grenade only ever resolves a single tile, so the "group" for
            // this attack is exactly one unit — tagged with the attacker side
            // so the modal can phrase it as "Enemy missile destroyed!" /
            // "Your missile is destroyed!" via the shared formatter.
            s.pendingDestructionAlerts.append(
                DestructionAlert(attacker: attacker, units: [unit])
            )
            // Any hit unit is removed from play so the AI/player can no longer
            // tap it as a launcher and the tile stops intercepting future
            // attacks. HQ is removed too — the game ends moments later via
            // `pendingEndGamePhase`, so the empty cell is only visible during
            // the cooldown beat.
            s.board.marks.removeValue(forKey: pos)
            if unit == .headquarters {
                s.pendingEndGamePhase = endGamePhase(forAttacker: attacker)
            }
        }
        startCooldown(state: &s, effects: &effects)
    }

    // MARK: - Bombing

    private static func handleConfirmBombTap(
        state s: inout GameState,
        source: GridPosition,
        pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = s.currentTurn
        guard Zones.isBombingTarget(pos, attacker: attacker) else { return }

        if Rules.bomberIntercepted(board: s.board, target: pos, attacker: attacker) {
            if attacker == .player {
                s.lastTurnHighlight = [pos]
                s.phase = .play(.bomberInterceptFlight(source: source, anchor: pos))
                return
            }
            s.lastTurnHighlight = [pos]
            s.phase = .play(.opponentBomberInterceptFlight(source: source, anchor: pos))
            return
        }

        if attacker == .opponent {
            beginDeferredOpponentImpact(
                state: &s,
                impact: .bomber(source: source, target: pos),
                target: pos,
                effects: &effects
            )
            return
        }

        beginPlayerBomberFlight(state: &s, source: source, target: pos, effects: &effects)
    }

    /// Player bomber: record impact + enter `.bombingDrops` at `dropsApplied: 0` with no
    /// drops yet — `BoardView` + `LivePlayerBomberFlight` drive `advanceBombDrop`. Opponent
    /// bombers use the same contract via `applyBomberFirstDrop` + `LiveOpponentBomberFlight`.
    private static func beginPlayerBomberFlight(
        state s: inout GameState,
        source: GridPosition,
        target pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = Side.player
        let drops = Rules.bombingPositions(target: pos, attacker: attacker)
        recordAttackImpact(state: &s, attacker: attacker, cells: [pos])
        s.inFlightBombDestructions = []
        guard !drops.isEmpty else {
            finalizeBombingRun(state: &s, source: source, attacker: attacker, effects: &effects)
            return
        }
        s.phase = .play(.bombingDrops(source: source, target: pos, dropsApplied: 0))
    }

    /// Enters `.bombingDrops` at `dropsApplied: 0` with no drops applied yet.
    /// Opponent path: `Action.applyOpponentImpact` after the impact scroll — `BoardView`
    /// + `LiveOpponentBomberFlight` then drive `advanceBombDrop` on the mirrored timeline.
    ///
    /// When the anchor sits near the defender's back row some drops walk off the board;
    /// an empty `drops` list finalises immediately.
    private static func applyBomberFirstDrop(
        state s: inout GameState,
        attacker: Side,
        source: GridPosition,
        target pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let drops = Rules.bombingPositions(target: pos, attacker: attacker)
        recordAttackImpact(state: &s, attacker: attacker, cells: [pos])
        s.inFlightBombDestructions = []
        guard !drops.isEmpty else {
            finalizeBombingRun(state: &s, source: source, attacker: attacker, effects: &effects)
            return
        }
        s.phase = .play(.bombingDrops(source: source, target: pos, dropsApplied: 0))
    }

    private static func handleAdvanceBombDrop(
        state s: inout GameState,
        source: GridPosition,
        target: GridPosition,
        dropsApplied n: Int,
        effects: inout [SideEffect]
    ) {
        let attacker = s.currentTurn
        let drops = Rules.bombingPositions(target: target, attacker: attacker)
        if n < drops.count {
            if attacker == .opponent { s.lastTurnHighlight.append(drops[n]) }
            applyBombDrop(state: &s, position: drops[n], attacker: attacker)
            effects.append(.haptic(.notification))
        }

        let next = n + 1
        if next < drops.count {
            s.phase = .play(.bombingDrops(source: source, target: target, dropsApplied: next))
        } else {
            // HQ end-game is set inside `applyBombDrop` the moment a drop
            // lands on the HQ, so we don't re-check the (now-empty) cells.
            finalizeBombingRun(state: &s, source: source, attacker: attacker, effects: &effects)
        }
    }

    /// Common tail for every bomber salvo: retire the launcher, flush the
    /// accumulated destruction list as one queued alert tagged with the
    /// attacker side (so the modal reads "2 enemy missiles destroyed!" or
    /// "Your 2 missiles and bomber are destroyed!" instead of one modal per
    /// drop), and start the post-attack cooldown.
    private static func finalizeBombingRun(
        state s: inout GameState,
        source: GridPosition,
        attacker: Side,
        effects: inout [SideEffect]
    ) {
        s.board.removeLauncher(at: source, requiring: .bomber, attacker: attacker)
        s.phase = .play(.idle)
        if !s.inFlightBombDestructions.isEmpty {
            s.pendingDestructionAlerts.append(
                DestructionAlert(attacker: attacker, units: s.inFlightBombDestructions)
            )
            s.inFlightBombDestructions = []
        }
        startCooldown(state: &s, effects: &effects)
    }

    /// Resolves a single bomb drop. Hits write a `.hit` overlay, append the
    /// destroyed unit to the in-flight accumulator (drained as one modal
    /// when the salvo finishes), remove the unit from play, and end the
    /// game when the HQ is the unit destroyed. Misses just leave a `.miss`
    /// water splash.
    private static func applyBombDrop(
        state s: inout GameState,
        position: GridPosition,
        attacker: Side
    ) {
        let defender = attacker.opposite
        if let unit = s.board.unit(at: position) {
            s.bombingOverlays[defender][position] = .hit
            s.inFlightBombDestructions.append(unit)
            s.board.marks.removeValue(forKey: position)
            if unit == .headquarters {
                s.pendingEndGamePhase = endGamePhase(forAttacker: attacker)
            }
        } else {
            s.bombingOverlays[defender][position] = .miss
        }
    }

    // MARK: - Missile

    private static func handleConfirmMissileTap(
        state s: inout GameState,
        source: GridPosition,
        pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = s.currentTurn
        guard Zones.isMissileTarget(pos, attacker: attacker) else { return }

        if Rules.missileIntercepted(board: s.board, anchor: pos, attacker: attacker) {
            if attacker == .player {
                s.lastTurnHighlight = [pos]
                s.phase = .play(.missileInterceptFlight(source: source, anchor: pos))
                return
            }
            s.lastTurnHighlight = [pos]
            s.phase = .play(.opponentMissileInterceptFlight(source: source, anchor: pos))
            return
        }

        if attacker == .opponent {
            beginOpponentMissileFlight(state: &s, source: source, anchor: pos, effects: &effects)
            return
        }

        beginPlayerMissileFlight(state: &s, source: source, anchor: pos, effects: &effects)
    }

    /// Player missile: fly-over (`missileFlight`); full X-pattern commits at once on
    /// `commitMissileFlightStrike`.
    private static func beginPlayerMissileFlight(
        state s: inout GameState,
        source: GridPosition,
        anchor pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = Side.player
        let drops = Rules.missileImpactApplicationOrder(anchor: pos, attacker: attacker)
        recordAttackImpact(state: &s, attacker: attacker, cells: [pos])
        s.inFlightBombDestructions = []
        guard !drops.isEmpty else {
            finalizePlayerMissileRun(state: &s, source: source, attacker: attacker, effects: &effects)
            return
        }
        s.phase = .play(.missileFlight(source: source, anchor: pos, attacker: .player))
    }

    private static func beginOpponentMissileFlight(
        state s: inout GameState,
        source: GridPosition,
        anchor pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = Side.opponent
        let drops = Rules.missileImpactApplicationOrder(anchor: pos, attacker: attacker)
        recordAttackImpact(state: &s, attacker: attacker, cells: [pos])
        s.inFlightBombDestructions = []
        guard !drops.isEmpty else {
            finalizePlayerMissileRun(state: &s, source: source, attacker: attacker, effects: &effects)
            return
        }
        s.phase = .play(.missileFlight(source: source, anchor: pos, attacker: attacker))
    }

    private static func finalizePlayerMissileRun(
        state s: inout GameState,
        source: GridPosition,
        attacker: Side,
        effects: inout [SideEffect]
    ) {
        if !s.inFlightBombDestructions.isEmpty {
            s.pendingDestructionAlerts.append(
                DestructionAlert(attacker: attacker, units: s.inFlightBombDestructions)
            )
            s.inFlightBombDestructions = []
        }
        s.board.removeLauncher(at: source, requiring: .missile, attacker: attacker)
        s.phase = .play(.idle)
        startCooldown(state: &s, effects: &effects)
    }

    /// Applies coastguard missile interception after `LiveMissileInterceptFlight.runMirrored` finishes.
    private static func commitOpponentMissileIntercept(
        state s: inout GameState,
        source: GridPosition,
        anchor: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = Side.opponent
        let wreckRow = Zones.shotDownRow(attacker: attacker)
        let wreckCol = anchor.col
        let wreckPos = GridPosition(wreckRow, wreckCol)
        s.missileInWater[attacker] = wreckPos
        s.board.removeLauncher(at: source, requiring: .missile, attacker: attacker)
        s.phase = .play(.shotDown(.missile, attacker: attacker))
        applyShotDownHighlight(state: &s, attacker: attacker, wreckPos: wreckPos, coastguardColumn: anchor.col)
        effects.append(.haptic(.notification))
        startCooldown(state: &s, effects: &effects, additionalSeconds: shotDownExtraCooldown)
    }

    /// Applies coastguard missile interception after `LiveMissileInterceptFlight` finishes.
    private static func commitPlayerMissileIntercept(
        state s: inout GameState,
        source: GridPosition,
        anchor: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = Side.player
        let wreckRow = Zones.shotDownRow(attacker: attacker)
        let wreckCol = anchor.col
        let wreckPos = GridPosition(wreckRow, wreckCol)
        s.missileInWater[attacker] = wreckPos
        s.board.removeLauncher(at: source, requiring: .missile, attacker: attacker)
        s.phase = .play(.shotDown(.missile, attacker: attacker))
        applyShotDownHighlight(state: &s, attacker: attacker, wreckPos: wreckPos, coastguardColumn: anchor.col)
        effects.append(.haptic(.notification))
        startCooldown(state: &s, effects: &effects, additionalSeconds: shotDownExtraCooldown)
    }

    /// Applies coastguard bomber interception after the same trailer as `LiveMissileInterceptFlight`.
    private static func commitPlayerBomberIntercept(
        state s: inout GameState,
        source: GridPosition,
        anchor: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = Side.player
        let wreckRow = Zones.shotDownRow(attacker: attacker)
        let wreckCol = anchor.col
        let wreckPos = GridPosition(wreckRow, wreckCol)
        s.planeInWater[attacker] = wreckPos
        s.board.removeLauncher(at: source, requiring: .bomber, attacker: attacker)
        s.phase = .play(.shotDown(.bomber, attacker: attacker))
        applyShotDownHighlight(state: &s, attacker: attacker, wreckPos: wreckPos, coastguardColumn: anchor.col)
        effects.append(.haptic(.notification))
        startCooldown(state: &s, effects: &effects, additionalSeconds: shotDownExtraCooldown)
    }

    /// Applies coastguard bomber interception after `LiveMissileInterceptFlight.runMirrored`.
    private static func commitOpponentBomberIntercept(
        state s: inout GameState,
        source: GridPosition,
        anchor: GridPosition,
        effects: inout [SideEffect]
    ) {
        let attacker = Side.opponent
        let wreckRow = Zones.shotDownRow(attacker: attacker)
        let wreckCol = anchor.col
        let wreckPos = GridPosition(wreckRow, wreckCol)
        s.planeInWater[attacker] = wreckPos
        s.board.removeLauncher(at: source, requiring: .bomber, attacker: attacker)
        s.phase = .play(.shotDown(.bomber, attacker: attacker))
        applyShotDownHighlight(state: &s, attacker: attacker, wreckPos: wreckPos, coastguardColumn: anchor.col)
        effects.append(.haptic(.notification))
        startCooldown(state: &s, effects: &effects, additionalSeconds: shotDownExtraCooldown)
    }

    /// Commits the full missile X-pattern: writes hit/miss overlays, removes a
    /// destroyed coastguard from the board, retires the launcher tile, and
    /// kicks off the post-attack cooldown. Used when `commitMissileFlightStrike` runs after the
    /// fly-over animation (player or opponent).
    private static func applyMissileSalvo(
        state s: inout GameState,
        attacker: Side,
        source: GridPosition,
        anchor pos: GridPosition,
        effects: inout [SideEffect]
    ) {
        let cells = Rules.missileImpactApplicationOrder(anchor: pos, attacker: attacker)
        recordAttackImpact(state: &s, attacker: attacker, cells: cells)
        s.inFlightBombDestructions = []
        s.missileSalvoGhostUnits = [:]
        var pulseHits = Set<GridPosition>()
        for c in cells {
            let hadUnit = s.board.unit(at: c) != nil
            applyMissileDropAtCell(state: &s, position: c, attacker: attacker)
            if hadUnit { pulseHits.insert(c) }
        }
        s.missileImpactPulseGeneration &+= 1
        s.missileSalvoPulseHitCells = pulseHits
        if !s.inFlightBombDestructions.isEmpty {
            s.pendingDestructionAlerts.append(
                DestructionAlert(attacker: attacker, units: s.inFlightBombDestructions)
            )
            s.inFlightBombDestructions = []
        }
        effects.append(.haptic(.notification))
        s.board.removeLauncher(at: source, requiring: .missile, attacker: attacker)
        s.phase = .play(.idle)
        startCooldown(state: &s, effects: &effects)
    }

    /// One cell of an X-pattern salvo — shared by `applyMissileSalvo` / `commitMissileFlightStrike`.
    private static func applyMissileDropAtCell(
        state s: inout GameState,
        position: GridPosition,
        attacker: Side
    ) {
        let defender = attacker.opposite
        if let unit = s.board.unit(at: position) {
            s.missileOverlays[defender][position] = .hit
            s.inFlightBombDestructions.append(unit)
            s.missileSalvoGhostUnits[position] = unit
            s.board.marks.removeValue(forKey: position)
            if unit == .headquarters {
                s.pendingEndGamePhase = endGamePhase(forAttacker: attacker)
            }
        } else {
            s.missileOverlays[defender][position] = .miss
        }
    }

    // MARK: - Turn management

    /// Records the orange impact highlight when the AI is the attacker (so the
    /// player can locate the incoming damage); clears it when the player attacks
    /// without being intercepted (previous AI hits should stop being marked).
    /// Player-attack interceptions are routed through `applyShotDownHighlight`,
    /// which writes its own highlight set, so this function never runs in that
    /// path.
    private static func recordAttackImpact(
        state s: inout GameState,
        attacker: Side,
        cells: [GridPosition]
    ) {
        switch attacker {
        case .opponent: s.lastTurnHighlight = cells
        case .player:   s.lastTurnHighlight = []
        }
    }

    /// Updates the orange highlight + camera after a coastguard interception.
    /// Symmetric — whichever side's coastguard shoots down the incoming weapon,
    /// we outline that defender's CG cell + the attacker's wreck cell and scroll
    /// to the seam between those rows so they're vertically centred on screen.
    /// Pass `coastguardColumn` when the interceptor is known from the attack anchor
    /// (multi-column coastguard row / DEBUG fill); otherwise the first CG column is used.
    private static func applyShotDownHighlight(
        state s: inout GameState,
        attacker: Side,
        wreckPos: GridPosition,
        coastguardColumn: Int? = nil
    ) {
        let defender = attacker.opposite
        let coastRow = Zones.coastguardRow(of: defender)
        let cgCol = coastguardColumn ?? s.board.coastguardColumn(of: defender)
        if let col = cgCol {
            let cgPos = GridPosition(coastRow, col)
            s.lastTurnHighlight = [cgPos, wreckPos]
        } else {
            // Defender CG already destroyed (shouldn't happen — interception
            // requires a live CG — but stay safe).
            s.lastTurnHighlight = [wreckPos]
        }
        s.requestScroll(toID: Zones.coastguardDefenseSeamID(defender: defender))
    }

    /// Locks the board for `cooldownDuration` so the player can absorb the just-
    /// rendered impact, then `Action.completeTurn` will lift the lock and flip
    /// the turn. Used after **every** bomb drop, the missile salvo, and grenade
    /// resolution — so the orange outline + explosion sticks for a full second
    /// before the next event.
    private static func startCooldown(
        state s: inout GameState,
        effects: inout [SideEffect],
        additionalSeconds: Double = 0
    ) {
        s.isInPostAttackCooldown = true
        effects.append(.scheduleCompleteTurn(afterSeconds: cooldownDuration + additionalSeconds))
    }

    /// Flips `currentTurn` after the active side has fully resolved an attack.
    ///
    /// Scroll behaviour: handled per-event, never on the turn flip itself.
    /// * **Player → Opponent**: no scroll on the flip; the AI's strike resolver
    ///   (`requestOpponentImpactScroll`) scrolls the camera to the specific
    ///   impact tile when the AI fires, so the player sees the camera follow
    ///   the just-launched attack instead of jumping to a fixed preview row.
    /// * **Opponent → Player**: no scroll. The camera is already pinned on the
    ///   AI's impact from the previous turn, where the just-hit cells are still
    ///   outlined in orange. Yanking up to the opponent's half would hide those
    ///   incoming-damage marks the moment the player got hit, which is the
    ///   opposite of what they want to see when planning their counterattack.
    private static func endTurn(state s: inout GameState) {
        s.currentTurn = s.currentTurn.opposite
    }

    /// Centres the AI's just-fired strike vertically. When the target sits in
    /// the bottom three rows we instead pin the very last row to the viewport
    /// bottom — the same camera position as the initial load — because the
    /// scroll view can't actually centre a row that has fewer than `viewport/2`
    /// rows beneath it.
    private static func requestOpponentImpactScroll(state s: inout GameState, target: GridPosition) {
        let bottomThresholdRow = Zones.rowCount - 3   // = 11; rows 11..13 anchor to the bottom.
        if target.row >= bottomThresholdRow {
            s.requestScroll(to: Zones.rowCount - 1, anchor: .bottom)
        } else {
            s.requestScroll(to: target.row, anchor: .center)
        }
    }

    /// Parks an AI strike in the "pending" slot, scrolls the camera to the
    /// target tile, and schedules `Action.applyOpponentImpact` to commit the
    /// overlays / haptics once the scroll animation has finished. The board
    /// remains visually unchanged for the duration of the scroll — the player
    /// sees the camera pan to the threatened tile before the explosion lands.
    private static func beginDeferredOpponentImpact(
        state s: inout GameState,
        impact: PendingOpponentImpact,
        target: GridPosition,
        effects: inout [SideEffect]
    ) {
        s.pendingOpponentImpact = impact
        requestOpponentImpactScroll(state: &s, target: target)
        effects.append(.scheduleApplyOpponentImpact(afterSeconds: opponentImpactScrollDuration))
    }

    /// Dispatches the queued opponent impact to the matching apply-helper. By
    /// the time this runs, the camera has finished panning to the target tile.
    private static func resolvePendingOpponentImpact(
        state s: inout GameState,
        pending: PendingOpponentImpact,
        effects: inout [SideEffect]
    ) {
        switch pending {
        case .grenade(let target):
            applyGrenadeImpact(state: &s, attacker: .opponent, target: target, effects: &effects)
        case .bomber(let source, let target):
            applyBomberFirstDrop(
                state: &s,
                attacker: .opponent,
                source: source,
                target: target,
                effects: &effects
            )
        }
    }

    /// HQ-hit terminal phase, picked from the perspective of the attacker.
    private static func endGamePhase(forAttacker attacker: Side) -> Phase {
        switch attacker {
        case .player: return .victory
        case .opponent: return .defeat
        }
    }

    /// Appends `scheduleOpponentTurn` whenever the resolved state expects the
    /// opponent to act next and no automatic timer (bomb-drop, cooldown) is
    /// already running. Idempotent-ish: callers invoke it once per reducer entry,
    /// not per mutation.
    private static func appendOpponentSchedulingIfNeeded(
        state s: GameState,
        effects: inout [SideEffect]
    ) {
        guard s.currentTurn == .opponent else { return }
        // Don't dispatch the AI while a destruction alert is up — wait for the
        // player to acknowledge it first.
        guard !s.isModalActive else { return }
        // Don't dispatch while we're holding the post-attack lock — `completeTurn`
        // will re-evaluate scheduling once the lock lifts.
        guard !s.isInPostAttackCooldown else { return }
        // Don't dispatch a fresh tap while the previous one is still mid-scroll.
        // `applyOpponentImpact` re-runs this scheduling tail once it lands.
        guard s.pendingOpponentImpact == nil else { return }
        guard case .play(let play) = s.phase else { return }

        let delay: Double
        switch play {
        case .bombingDrops:
            return                                     // advanceBombDrop drives this
        case .missileFlight:
            return                                     // `commitMissileFlightStrike` ends flight
        case .missileInterceptFlight, .bomberInterceptFlight, .opponentMissileInterceptFlight,
             .opponentBomberInterceptFlight:
            return                                     // coastguard intercept trailer
        case .shotDown:
            delay = opponentPostShotDownDelay
        case .choosingBombTarget, .choosingMissileTarget:
            delay = opponentInterTapDelay              // mid-turn step
        case .idle:
            delay = opponentPostAttackDelay
        }
        effects.append(.scheduleOpponentTurn(afterSeconds: delay))
    }
}
