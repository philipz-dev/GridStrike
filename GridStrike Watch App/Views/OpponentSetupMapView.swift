//
//  OpponentSetupMapView.swift
//  HQStrike Watch App
//
//  Post-game frozen snapshot at round start (`boardAtPlayStart`). Layout deliberately
//  mirrors `BoardView` (same tile width, horizontal padding). Dismiss with the same
//  top-leading × placement as weapon demos (`DemoTopCloseButton` math).
//
//  Top bar: `InstructionBanner` + `BannerKind.postGameSetupMap` (“Setup”), positioned
//  like `PlayContainerView`’s banner stack (no extra top inset — matches in-game bar).
//

import SwiftUI

struct OpponentSetupMapView: View {
    let frozenBoard: Board
    let onClose: () -> Void

    private static let bannerKind = BannerKind.postGameSetupMap

    var body: some View {
        GeometryReader { geo in
            let tileWidth = floor(BoardGridMetrics.tileWidth(forContainerWidth: geo.size.width))

            ZStack(alignment: .topLeading) {
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
                    .allowsHitTesting(false)
                }
                .scrollIndicators(.visible)

                VStack(spacing: 0) {
                    InstructionBanner(banner: Self.bannerKind)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                TopLeadingTacticalCloseBar(
                    isVisible: true,
                    accessibilityLabel: "Close setup map",
                    accessibilityHint: "Returns to the menu",
                    screenHeight: geo.size.height,
                    action: onClose
                )
            }
        }
        .background(Color.black.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.bannerKind.localized)
        .accessibilityHint("Returns to the menu.")
    }

    /// Neutral map cells: no overlays, no ghost dim, no disabled-button
    /// dimming. Tap actions are no-ops (`onTap: {}`) so the map is read-only,
    /// but `isDisabled: false` keeps the artwork at full brightness instead
    /// of the muted half-opacity SwiftUI gives to a disabled plain Button.
    /// Opponent-zone unit art is suppressed when
    /// **`!HQStrikeDebug.showAllEnemyObjectsOnPostGameMap`** (DEBUG only).
    private func makeModel(for pos: GridPosition) -> TileRenderModel {
        let isOpponentZone = pos.row <= Zones.coastguardEnemyRow

#if DEBUG
        let obscureEnemyPieces = isOpponentZone && !HQStrikeDebug.showAllEnemyObjectsOnPostGameMap
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
            dropOverlayScale: 1,
            missileHitPulseToken: nil,
            waterWreck: nil,
            wreckRotationDegrees: 0,
            border: .plain,
            isLastTurnHighlight: false,
            isDisabled: false
        )
    }
}
