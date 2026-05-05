//
//  TileView.swift
//  GridStrike Watch App
//
//  Pure presentation. The view's only input is a `TileRenderModel`; the closure is
//  ignored when computing equality so SwiftUI can short-circuit redraws.
//

import SwiftUI

struct TileView: View, Equatable {
    let model: TileRenderModel
    let tileSize: CGFloat
    let onTap: () -> Void

    static func == (lhs: TileView, rhs: TileView) -> Bool {
        lhs.model == rhs.model && lhs.tileSize == rhs.tileSize
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                background
                ghostScrim
                offCoastguardScrim
                strikeOverlayView
                dropOverlayView
                wreckOverlayView
                borderRect
            }
            .compositingGroup()
            .opacity(model.offCoastguardFocusRow ? 0.88 : 1)
            .frame(width: tileSize, height: tileSize)
            .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isDisabled)
    }

    // MARK: - Layers

    private var dimmed: Bool { model.dim != .none }
    private var coastguardOffRowGhost: Bool { model.dim == .coastguardOffRow }
    private var dimmedNotFocus: Bool { dimmed && !model.offCoastguardFocusRow }

    @ViewBuilder
    private var background: some View {
        Assets.tileImage(for: model.background)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .clipped()
            .rotationEffect(.degrees(model.bomberRotationDegrees))
            .saturation(model.offCoastguardFocusRow ? 1 : (coastguardOffRowGhost ? 0.88 : 1))
            .brightness(dimmedNotFocus ? (coastguardOffRowGhost ? -0.04 : 0.05) : 0)
            .opacity(dimmedNotFocus ? (coastguardOffRowGhost ? 0.86 : 0.99) : 1)
    }

    @ViewBuilder
    private var ghostScrim: some View {
        if dimmedNotFocus {
            Color.white.opacity(coastguardOffRowGhost ? 0.16 : 0.08)
        }
    }

    @ViewBuilder
    private var offCoastguardScrim: some View {
        if model.offCoastguardFocusRow {
            Color.black.opacity(0.32)
        }
    }

    @ViewBuilder
    private var strikeOverlayView: some View {
        if let kind = model.northStrikeOverlay {
            Assets.explosionImage(for: kind)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: tileSize * 0.92, height: tileSize * 0.92)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var dropOverlayView: some View {
        if let kind = model.dropOverlay {
            Assets.explosionImage(for: kind)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: tileSize * 0.92, height: tileSize * 0.92)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var wreckOverlayView: some View {
        switch model.waterWreck {
        case .plane:
            wreckImage(Assets.planeInWater)
        case .missile:
            wreckImage(Assets.missileInWater)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func wreckImage(_ image: Image) -> some View {
        image
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: tileSize * 0.88, height: tileSize * 0.88)
            .foregroundStyle(Color(red: 0.34, green: 0.34, blue: 0.36))
            .rotationEffect(.degrees(model.wreckRotationDegrees))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var borderRect: some View {
        let isSelected = model.border == .selected
        let isHighlighted = model.isLastTurnHighlight && !isSelected
        let strokeColor: Color = {
            if isSelected { return .red }
            if isHighlighted { return .orange }
            if dimmed { return Color.black.opacity(coastguardOffRowGhost ? 0.5 : 0.42) }
            return .black
        }()
        let strokeWidth: CGFloat = {
            if isSelected { return 2.5 }
            if isHighlighted { return 2.5 }
            return dimmed ? 1.5 : 2
        }()
        Rectangle()
            .strokeBorder(strokeColor, lineWidth: strokeWidth)
    }
}
