//
//  DemoScriptedOutlineHaptic.swift
//  HQStrike Watch App
//
//  Shared tactile for scripted “finger down” beats when orange outlines appear.
//  Uses `WKHapticType.start` (beginning-of-action) instead of `.click`, which is
//  documented as carrying a miniature click sound.
//

import WatchKit

enum DemoScriptedOutlineHaptic {
    @MainActor
    static func playAtOutlinePress() {
        WKInterfaceDevice.current().play(.start)
    }
}
