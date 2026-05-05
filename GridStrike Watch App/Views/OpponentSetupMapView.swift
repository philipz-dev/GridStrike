//
//  OpponentSetupMapView.swift
//  GridStrike Watch App
//
//  Post-game frozen snapshot at round start (`boardAtPlayStart`). Layout deliberately
//  mirrors `BoardView` (same tile width, no extra top/bottom gutter, same horizontal
//  padding) so the map renders in the **original grid colours** instead of looking
//  shrunken or ghosted inside a dark frame. The close button rides as a non-flow
//  overlay anchored to the very top-left corner.
//

import SwiftUI

struct OpponentSetupMapView: View {
    let frozenBoard: Board
    let onClose: () -> Void

    private static let closeButtonSize: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let tileWidth = BoardGridMetrics.tileWidth(forContainerWidth: geo.size.width)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(0..<BoardGridMetrics.rowCount, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<BoardGridMetrics.columnCount, id: \.self) { col in
                                let pos = GridPosition(row, col)
                                TileView(
                                    model: makeModel(for: pos),
                                    tileSize: tileWidth,
                                    onTap: {}
                                )
                                .equatable()
                            }
                        }
                        .frame(height: tileWidth)
                    }
                }
                .padding(.horizontal, BoardGridMetrics.horizontalPadding)
            }
            .scrollIndicators(.visible)
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            // Floating close button — pinned to the very top-left of the
            // safe area (no left/top padding) so the X reads as a proper
            // corner control rather than floating inside the grid. Does not
            // consume flow space, so the grid below starts at the same
            // position as during normal gameplay.
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: Self.closeButtonSize, height: Self.closeButtonSize)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    /// Neutral map cells: no overlays, no ghost dim, no disabled-button
    /// dimming. Tap actions are no-ops (`onTap: {}`) so the map is read-only,
    /// but `isDisabled: false` keeps the artwork at full brightness instead
    /// of the muted half-opacity SwiftUI gives to a disabled plain Button.
    /// Opponent-zone unit art is suppressed when
    /// **`!GridStrikeDebug.showAllEnemyObjectsOnPostGameMap`** (DEBUG only).
    private func makeModel(for pos: GridPosition) -> TileRenderModel {
        let isOpponentZone = pos.row <= Zones.coastguardEnemyRow

#if DEBUG
        let obscureEnemyPieces = isOpponentZone && !GridStrikeDebug.showAllEnemyObjectsOnPostGameMap
#else
        let obscureEnemyPieces = false
#endif

        let mark: Unit? = obscureEnemyPieces ? nil : frozenBoard.unit(at: pos)

        let background: TileBackground = {
            if let mark = mark { return .unit(mark) }
            return Zones.isWater(pos.row) ? .water : .grass
        }()

        let bomberRotation: Double = {
            guard mark == .bomber else { return 0 }
            return frozenBoard.bomberRotations[pos] ?? 0
        }()

        return TileRenderModel(
            position: pos,
            background: background,
            bomberRotationDegrees: bomberRotation,
            dim: .none,
            offCoastguardFocusRow: false,
            northStrikeOverlay: nil,
            dropOverlay: nil,
            waterWreck: nil,
            wreckRotationDegrees: 0,
            border: .plain,
            isLastTurnHighlight: false,
            isDisabled: false
        )
    }
}
