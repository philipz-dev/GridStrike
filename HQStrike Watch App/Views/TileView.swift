//
//  TileView.swift
//  HQStrike Watch App
//
//  Pure presentation. The view's only input is a `TileRenderModel`; the closure is
//  ignored when computing equality so SwiftUI can short-circuit redraws.
//

import SwiftUI

struct TileView: View, Equatable {
    let model: TileRenderModel
    let tileSize: CGFloat
    let onTap: () -> Void

    @State private var missileHitPulseScale: CGFloat = 1
    @State private var lastAppliedMissileHitPulseToken: UInt32?

    static func == (lhs: TileView, rhs: TileView) -> Bool {
        lhs.model == rhs.model && lhs.tileSize == rhs.tileSize
    }

    var body: some View {
        // IMPORTANT — modifier order is load-bearing for hit testing:
        //   1. `.frame` first, BEFORE `.compositingGroup()`/`.opacity()`/`.clipShape`,
        //      so the gesture recognizer is anchored to a stable `tileSize × tileSize`
        //      box. With `.frame` applied *after* a compositing group, the recognizer
        //      sometimes follows the ZStack's intrinsic bounds (which grow during the
        //      missile-hit `scaleEffect(2.0)` pulse) and taps drift onto adjacent rows.
        //   2. `.contentShape` and `.onTapGesture` next, before any visual modifiers,
        //      so the hit area is *exactly* the drawn tile rectangle.
        //   3. `.compositingGroup` / `.clipShape` last (rendering-only).
        // `Button`+`.plain` enforces a ~44pt minimum touch target on watchOS, which
        // makes adjacent ~36pt tiles overlap vertically — `.onTapGesture` does not.
        ZStack {
            background
            ghostScrim
            offCoastguardScrim
            strikeOverlayView
            dropOverlayView
            wreckOverlayView
            borderRect
        }
        .frame(width: tileSize, height: tileSize, alignment: .topLeading)
        .contentShape(.rect)
        .onTapGesture {
            guard !model.isDisabled else { return }
            onTap()
        }
        .compositingGroup()
        .opacity(model.offCoastguardFocusRow ? 0.88 : 1)
        .clipShape(Rectangle())
        .onChange(of: model.missileHitPulseToken) { _, new in
            guard new == nil else { return }
            lastAppliedMissileHitPulseToken = nil
            missileHitPulseScale = 1
        }
        .onChange(of: model.dropOverlay) { _, new in
            guard new == .hit else {
                lastAppliedMissileHitPulseToken = nil
                missileHitPulseScale = 1
                return
            }
        }
    }

    /// `onChange(of:)` does not run on first paint; `onAppear` covers that. Reset when the overlay clears so replays with the same token still pulse.
    private func runMissileHitPulseAnimation(from token: UInt32) {
        guard lastAppliedMissileHitPulseToken != token else { return }
        lastAppliedMissileHitPulseToken = token
        missileHitPulseScale = 0.5
        withAnimation(.easeOut(duration: 0.12)) {
            missileHitPulseScale = 2.0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) {
                    missileHitPulseScale = 1.0
                }
            }
        }
    }

    // MARK: - Layers

    private var dimmed: Bool { model.dim != .none }
    private var coastguardOffRowGhost: Bool { model.dim == .coastguardOffRow }
    private var dimmedNotFocus: Bool { dimmed && !model.offCoastguardFocusRow }

    /// Slightly translucent hit explosion when a unit tile sits underneath so it stays readable through 50%→200%→100% pulse.
    private var missileHitExplosionOpacity: CGFloat {
        if case .unit = model.background { return 0.88 }
        return 1
    }

    @ViewBuilder
    private var background: some View {
        Assets.tileImage(for: model.background, at: model.position)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .clipped()
            .rotationEffect(.degrees(model.bomberRotationDegrees))
            .transaction { $0.animation = nil }
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
            if kind == .hit, model.missileHitPulseToken != nil {
                Assets.explosionImage(for: kind)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: tileSize * 0.92, height: tileSize * 0.92)
                    .scaleEffect(model.dropOverlayScale * missileHitPulseScale)
                    .opacity(missileHitExplosionOpacity)
                    .allowsHitTesting(false)
                    .onAppear {
                        if let token = model.missileHitPulseToken {
                            runMissileHitPulseAnimation(from: token)
                        }
                    }
                    .onChange(of: model.missileHitPulseToken) { _, token in
                        guard let token else { return }
                        runMissileHitPulseAnimation(from: token)
                    }
            } else {
                Assets.explosionImage(for: kind)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: tileSize * 0.92, height: tileSize * 0.92)
                    .scaleEffect(model.dropOverlayScale)
                    .allowsHitTesting(false)
            }
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
