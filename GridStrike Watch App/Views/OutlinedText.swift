//
//  OutlinedText.swift
//  HQStrike Watch App
//
//  White text crisply outlined in black for use over a busy photographic
//  background. Built from a ZStack of eight offset copies of the label
//  (one per compass direction) drawn in the outline colour, with the fill
//  version drawn on top — gives a hard, even border at any font size,
//  unlike a soft `.shadow` which would smear.
//
//  Prefer **one line per `OutlinedText`** on watchOS; multi-line strings can be
//  laid out with several views in a `VStack` (see welcome splash).
//
//  Used by the welcome splash and the help-screen header so titles stay
//  readable against any backdrop (parchment scroll, sunset sky, or wreck
//  artwork) without resorting to a blurred drop shadow.
//

import SwiftUI

struct OutlinedText: View {
    let content: String
    let font: Font
    let fill: Color
    let outline: Color
    let outlineWidth: CGFloat

    init(
        _ content: String,
        font: Font,
        fill: Color = .white,
        outline: Color = .black,
        outlineWidth: CGFloat = 1
    ) {
        self.content = content
        self.font = font
        self.fill = fill
        self.outline = outline
        self.outlineWidth = outlineWidth
    }

    var body: some View {
        ZStack {
            outlineLayer(dx: -1, dy: -1)
            outlineLayer(dx:  0, dy: -1)
            outlineLayer(dx:  1, dy: -1)
            outlineLayer(dx: -1, dy:  0)
            outlineLayer(dx:  1, dy:  0)
            outlineLayer(dx: -1, dy:  1)
            outlineLayer(dx:  0, dy:  1)
            outlineLayer(dx:  1, dy:  1)
            Text(content).foregroundStyle(fill)
        }
        .font(font)
    }

    private func outlineLayer(dx: CGFloat, dy: CGFloat) -> some View {
        Text(content)
            .foregroundStyle(outline)
            .offset(x: dx * outlineWidth, y: dy * outlineWidth)
    }
}
