//
//  EndGamePalette.swift
//  GridStrike Watch App
//
//  Muted pill tints for the start menu / manual paths. Kept
//  deliberately less bright than system greens / reds so buttons support the
//  artwork rather than out-shouting it.
//

import SwiftUI

enum EndGamePalette {
    /// Forest-style green — desaturated vs `.green`.
    static let mutedGreen = Color(red: 0.20, green: 0.50, blue: 0.25)

    /// Brick-style red — dimmer than system `.red`.
    static let mutedRed = Color(red: 0.55, green: 0.20, blue: 0.20)

    /// Slate grey — solid, deliberately dim vs system `.gray`.
    static let mutedGray = Color(red: 0.34, green: 0.34, blue: 0.38)
}
