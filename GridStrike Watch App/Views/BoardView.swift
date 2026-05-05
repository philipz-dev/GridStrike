//
//  BoardView.swift
//  GridStrike Watch App
//
//  Scrollable 14×5 grid. Reads only from the precomputed snapshot — every tap is
//  forwarded as `Action.tap(GridPosition)`. Reacts to `state.scrollRequest` so the
//  reducer can pull the camera to whichever half is in the spotlight (the
//  opponent's grass when the player is up, the player's grass when the AI is up).
//

import SwiftUI

struct BoardView: View {
    let snapshot: BoardSnapshot
    @Environment(GameStore.self) private var store
    @State private var didInitialScroll = false

    private static let rows = BoardGridMetrics.rowCount
    private static let bottomCurveTapReserve: CGFloat = 10

    private var bottomRowScrollId: String { "row-\(Self.rows - 1)" }

    var body: some View {
        let scrollRequest = store.state.scrollRequest

        GeometryReader { geo in
            let tileSize = BoardGridMetrics.tileWidth(forContainerWidth: geo.size.width)
            let bottomInset = geo.safeAreaInsets.bottom
            let pullDown = max(0, bottomInset - Self.bottomCurveTapReserve)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(0..<Self.rows, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<BoardGridMetrics.columnCount, id: \.self) { col in
                                    let pos = GridPosition(row, col)
                                    if let model = snapshot.tiles[pos] {
                                        TileView(
                                            model: model,
                                            tileSize: tileSize,
                                            onTap: { store.send(.tap(pos)) }
                                        )
                                        .equatable()
                                    }
                                }
                            }
                            .frame(height: tileSize)
                            .id("row-\(row)")

                            // 0-pt anchors used by the reducer to centre row pairs
                            // around shoot-down events — placed *between* their two
                            // rows so `scrollTo(_:anchor: .center)` puts the seam at
                            // the viewport centre.
                            // Row 5 ↔ 6: enemy CG + player wreck (player's attack
                            // got intercepted).
                            // Row 7 ↔ 8: opponent wreck + player CG (player's CG
                            // intercepted an AI attack).
                            if row == 5 {
                                Color.clear
                                    .frame(height: 0)
                                    .id(Zones.opponentDefenseSeamID)
                            }
                            if row == 7 {
                                Color.clear
                                    .frame(height: 0)
                                    .id(Zones.playerDefenseSeamID)
                            }
                        }
                    }
                    .padding(.horizontal, BoardGridMetrics.horizontalPadding)
                    .padding(.bottom, -pullDown)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                .onAppear {
                    guard !didInitialScroll else { return }
                    didInitialScroll = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        proxy.scrollTo(bottomRowScrollId, anchor: .bottom)
                    }
                }
                .onChange(of: scrollRequest) { _, newValue in
                    guard let request = newValue else { return }
                    let anchor: UnitPoint = {
                        switch request.anchor {
                        case .center: return .center
                        case .bottom: return .bottom
                        }
                    }()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            proxy.scrollTo(request.id, anchor: anchor)
                        }
                    }
                }
            }
        }
    }
}
