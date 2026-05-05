//
//  InstructionBanner.swift
//  GridStrike Watch App
//
//  Bound to a typed `BannerKind`; no game logic. Equatable so SwiftUI skips identical
//  redraws while overlays are running. Renders the message inside a full-width
//  semi-transparent dark bar that sits **behind** the text — board art shows through
//  but the white copy stays legible at watch sizes.
//

import SwiftUI

struct InstructionBanner: View, Equatable {
    let banner: BannerKind

    var body: some View {
        if banner.localized.isEmpty {
            EmptyView()
        } else {
            Text(banner.localized)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundStyle(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.55))
        }
    }
}
