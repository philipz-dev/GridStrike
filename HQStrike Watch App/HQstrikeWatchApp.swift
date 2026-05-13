//
//  HQStrikeWatchApp.swift
//  HQStrike Watch App
//
//  App entry. Owns the single GameStore via @State and injects it into the view tree
//  through the new Observable-aware environment.
//

import SwiftUI

@main
struct HQStrikeWatchApp: App {
    @State private var store: GameStore

    init() {
        Assets.warmFlightOverlayDecoding()
        _store = State(initialValue: GameStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
