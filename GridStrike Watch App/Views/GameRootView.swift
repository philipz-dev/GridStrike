//
//  GameRootView.swift
//  GridStrike Watch App
//
//  Top-level switch — welcome vs. play container, plus the modal overlays. Uses one
//  exhaustive switch over `UIMode` instead of separate optional/bool checks. Owns
//  the post-game "Map" toggle so VictoryOverlay/DefeatOverlay can flip into a
//  full-screen reveal of the AI's setup.
//

import SwiftUI

struct GameRootView: View {
    @Environment(GameStore.self) private var store
    @State private var showOpponentMap = false

    var body: some View {
        let snapshot = BoardSnapshot.compute(store.state)

        ZStack {
            switch store.state.mode {
            case .welcome:
                WelcomeView()

            case .destructionAlert(let alert):
                PlayContainerView(snapshot: snapshot)
                DestructionAlertOverlay(alert: alert) {
                    store.send(.acknowledgeDestructionAlert)
                }

            case .victory:
                if showOpponentMap {
                    // No PlayContainerView behind — keep the frozen map exactly as
                    // bright as the live grid (any bleed-through from the live
                    // explosion overlays makes it read as ghosted/dark).
                    OpponentSetupMapView(
                        frozenBoard: store.state.boardAtPlayStart ?? store.state.board
                    ) {
                        showOpponentMap = false
                    }
                } else {
                    PlayContainerView(snapshot: snapshot)
                    VictoryOverlay(
                        onNewGame: {
                            showOpponentMap = false
                            store.send(.newGame)
                        },
                        onShowMap: { showOpponentMap = true }
                    )
                }

            case .defeat:
                if showOpponentMap {
                    OpponentSetupMapView(
                        frozenBoard: store.state.boardAtPlayStart ?? store.state.board
                    ) {
                        showOpponentMap = false
                    }
                } else {
                    PlayContainerView(snapshot: snapshot)
                    DefeatOverlay(
                        onNewGame: {
                            showOpponentMap = false
                            store.send(.newGame)
                        },
                        onShowMap: { showOpponentMap = true }
                    )
                }

            case .setup, .play:
                PlayContainerView(snapshot: snapshot)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PlayContainerView: View {
    let snapshot: BoardSnapshot
    @Environment(GameStore.self) private var store

    var body: some View {
        ZStack(alignment: .topLeading) {
            BoardView(snapshot: snapshot)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(!store.state.isModalActive)

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
