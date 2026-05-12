//
//  GameRootView.swift
//  GridStrike Watch App
//
//  Top-level switch — `.welcome` shows `StartView` (splash + tactical menu); in-game UI is
//  `PlayContainerView` with modal overlays. One exhaustive switch over `UIMode`. After a win
//  or loss, Victory/Defeat appears first; tap anywhere to show the frozen round-start map;
//  tap the map to return to `.welcome` with the tactical menu open (splash skipped).
//

import SwiftUI

struct GameRootView: View {
    @Environment(GameStore.self) private var store
    /// After the outcome screen, shows `OpponentSetupMapView` (**Map overview**) until the player taps to dismiss.
    @State private var showPostGameStartingBoardMap = false

    var body: some View {
        let snapshot = BoardSnapshot.compute(store.state)

        ZStack {
            switch store.state.mode {
            case .welcome:
                StartView()
                    .transition(.opacity)

            case .destructionAlert(let alert):
                PlayContainerView(snapshot: snapshot)
                DestructionAlertOverlay(alert: alert) {
                    store.send(.acknowledgeDestructionAlert)
                }

            case .victory:
                if showPostGameStartingBoardMap {
                    OpponentSetupMapView(
                        frozenBoard: store.state.boardAtPlayStart ?? store.state.board
                    ) {
                        store.send(.finishPostGameMapReview)
                    }
                } else {
                    PlayContainerView(snapshot: snapshot)
                    VictoryOverlay {
                        showPostGameStartingBoardMap = true
                    }
                }

            case .defeat:
                if showPostGameStartingBoardMap {
                    OpponentSetupMapView(
                        frozenBoard: store.state.boardAtPlayStart ?? store.state.board
                    ) {
                        store.send(.finishPostGameMapReview)
                    }
                } else {
                    PlayContainerView(snapshot: snapshot)
                    DefeatOverlay {
                        showPostGameStartingBoardMap = true
                    }
                }

            case .setupConfirm:
                // Live board stays visible underneath the floating buttons so
                // the player can review their layout before locking it in.
                PlayContainerView(snapshot: snapshot)
                    .transition(.opacity)
                SetupConfirmOverlay(
                    onRestart: { store.send(.restartSetup) },
                    onConfirm: { store.send(.confirmSetup) }
                )

            case .setup, .play:
                PlayContainerView(snapshot: snapshot)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        /// Fade only when leaving or entering the start menu so in-game overlays (e.g. destruction) don’t flash.
        .animation(.easeInOut(duration: 0.32), value: store.state.mode == .welcome)
        .onChange(of: store.state.mode) { old, new in
            switch new {
            case .victory, .defeat:
                if case .victory = old {} else if case .defeat = old {} else {
                    showPostGameStartingBoardMap = false
                }
            default:
                showPostGameStartingBoardMap = false
            }
        }
    }
}

private struct PlayContainerView: View {
    let snapshot: BoardSnapshot
    @Environment(GameStore.self) private var store

    /// Same “ignore taps” window as the reducer’s `.bombingDrops` branch — keeps the grid
    /// from eating gestures while impacts are rolling (player flight is driven by `BoardView`).
    private var boardAllowsHitTesting: Bool {
        if store.state.isModalActive { return false }
        if case .play(.bombingDrops) = store.state.phase { return false }
        if case .play(.missileFlight) = store.state.phase { return false }
        if case .play(.missileInterceptFlight) = store.state.phase { return false }
        if case .play(.bomberInterceptFlight) = store.state.phase { return false }
        if case .play(.opponentMissileInterceptFlight) = store.state.phase { return false }
        if case .play(.opponentBomberInterceptFlight) = store.state.phase { return false }
        return true
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            BoardView(snapshot: snapshot)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(boardAllowsHitTesting)

            // Banner pinned to top — VStack + Spacer keeps multi-line text top-anchored
            // (Text in a maxHeight overlay would otherwise vertically center). The bar
            // sits just below the safe-area top edge so it's only slightly taller than
            // the text itself; no negative offset (which would push it behind the
            // watchOS status area and look like it extends to the bezel).
            VStack(spacing: 0) {
                InstructionBanner(banner: snapshot.banner)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
