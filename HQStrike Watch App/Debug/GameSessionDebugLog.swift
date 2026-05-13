//
//  GameSessionDebugLog.swift
//  HQStrike Watch App
//
//  DEBUG-only NDJSON session log for correlating reducer transitions with UI issues
//  (e.g. ScrollView tap offset after opponent missile). Enable via
//  `HQStrikeDebug.logReduceTransitionsToDocuments`.
//

import Foundation

#if DEBUG

// MARK: - Ordinal tracking (human-facing “enemy move N”)

/// Counts committed strikes for bug reports; updated before each log line.
struct GameDebugStrikeOrdinals: Equatable, Encodable {
    var opponentStrikeOrdinal: Int
    var playerStrikeOrdinal: Int
    var completeTurnOrdinal: Int
}

enum GameSessionDebugLog {
    /// Latest log file URL after a successful write (inspect in debugger).
    private(set) static var lastWrittenFileURL: URL?

    private static var ordinalTracker = OrdinalTracker()
    private static var reduceSeq = 0
    private static var didWriteSessionHeader = false

    private struct OrdinalTracker {
        var opponentStrikeOrdinal = 0
        var playerStrikeOrdinal = 0
        var completeTurnOrdinal = 0

        mutating func advance(old: GameState, action: Action, new: GameState) -> GameDebugStrikeOrdinals {
            if action == .completeTurn, case .play = old.phase {
                completeTurnOrdinal += 1
            }
            if action == .applyOpponentImpact {
                opponentStrikeOrdinal += 1
            }
            if case .tap = action {
                if case .play(.missileFlight(_, _, .opponent)) = new.phase {
                    if case .play(.missileFlight(_, _, .opponent)) = old.phase { } else {
                        opponentStrikeOrdinal += 1
                    }
                }
                if case .play(.missileFlight(_, _, .player)) = new.phase {
                    if case .play(.missileFlight(_, _, .player)) = old.phase { } else {
                        playerStrikeOrdinal += 1
                    }
                }
                if case .play(.bombingDrops(_, _, 0)) = new.phase, new.currentTurn == .player {
                    if case .play(.bombingDrops) = old.phase { } else {
                        playerStrikeOrdinal += 1
                    }
                }
            }
            return GameDebugStrikeOrdinals(
                opponentStrikeOrdinal: opponentStrikeOrdinal,
                playerStrikeOrdinal: playerStrikeOrdinal,
                completeTurnOrdinal: completeTurnOrdinal
            )
        }
    }

    private struct SessionHeader: Encodable {
        let kind: String
        let schemaVersion: Int
        let coordinateSystem: String
        let startedAt: String
    }

    private struct ReduceLine: Encodable {
        let kind: String
        let seq: Int
        let action: String
        let actionDetail: [String: String]?
        let phaseAfter: String
        let uiMode: String
        let turn: String
        let pendingOpponentImpact: String?
        let scrollRequest: ScrollRequestLine?
        let flags: FlagsLine
        let derived: GameDebugStrikeOrdinals
    }

    private struct ScrollRequestLine: Encodable {
        let id: String
        let token: Int
        let anchor: String
    }

    private struct FlagsLine: Encodable {
        let isInPostAttackCooldown: Bool
        let isModalActive: Bool
        let allowsPlayfieldScrolling: Bool
        let acceptsPlayerInput: Bool
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    static func appendAfterReduce(old: GameState, action: Action, new: GameState) {
        guard HQStrikeDebug.logReduceTransitionsToDocuments else { return }

        if action == .newGame || action == .confirmSetup {
            ordinalTracker = OrdinalTracker()
            reduceSeq = 0
            didWriteSessionHeader = false
            if let url = logFileURL() {
                try? FileManager.default.removeItem(at: url)
            }
        }

        reduceSeq += 1
        let derived = ordinalTracker.advance(old: old, action: action, new: new)

        if !didWriteSessionHeader {
            didWriteSessionHeader = true
            writeSessionHeaderIfNeeded()
        }

        let line = ReduceLine(
            kind: "reduce",
            seq: reduceSeq,
            action: actionLabel(action),
            actionDetail: actionDetail(action),
            phaseAfter: phasePath(new.phase),
            uiMode: uiModeLabel(new.mode),
            turn: String(describing: new.currentTurn),
            pendingOpponentImpact: pendingLabel(new.pendingOpponentImpact),
            scrollRequest: new.scrollRequest.map {
                ScrollRequestLine(
                    id: $0.id,
                    token: $0.token,
                    anchor: $0.anchor == .center ? "center" : "bottom"
                )
            },
            flags: FlagsLine(
                isInPostAttackCooldown: new.isInPostAttackCooldown,
                isModalActive: new.isModalActive,
                allowsPlayfieldScrolling: new.allowsPlayfieldScrolling,
                acceptsPlayerInput: new.acceptsPlayerInput
            ),
            derived: derived
        )

        appendJSON(line)
    }

    /// Optional manual marker (e.g. bind to a debug button later).
    static func appendBugMarker(note: String) {
        guard HQStrikeDebug.logReduceTransitionsToDocuments else { return }
        struct Marker: Encodable {
            let kind: String
            let seq: Int
            let note: String
            let at: String
        }
        let m = Marker(kind: "marker", seq: reduceSeq, note: note, at: iso8601.string(from: Date()))
        appendJSON(m)
    }

    private static func writeSessionHeaderIfNeeded() {
        let header = SessionHeader(
            kind: "header",
            schemaVersion: 1,
            coordinateSystem:
                "rows 0=north (opponent grass) .. 13=south (player grass), cols 0..4 west-east; cells \"r_c\" e.g. anchor 12_3.",
            startedAt: iso8601.string(from: Date())
        )
        appendJSON(header, freshFile: true)
    }

    private static func appendJSON<T: Encodable>(_ value: T, freshFile: Bool = false) {
        guard let url = logFileURL() else { return }
        do {
            let data = try encoder.encode(value)
            var line = data
            line.append(0x0A)

            if freshFile || !FileManager.default.fileExists(atPath: url.path) {
                try line.write(to: url, options: .atomic)
            } else {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                try handle.close()
            }
            lastWrittenFileURL = url
        } catch {
            // Avoid crashing gameplay if the container is full or sandbox rejects writes.
        }
    }

    private static func logFileURL() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent("hqstrike_reduce_debug.ndjson", isDirectory: false)
    }

    private static func actionLabel(_ action: Action) -> String {
        switch action {
        case .dismissWelcome: return "dismissWelcome"
        case .tap: return "tap"
        case .advanceBombDrop: return "advanceBombDrop"
        case .commitMissileFlightStrike: return "commitMissileFlightStrike"
        case .completeTurn: return "completeTurn"
        case .applyOpponentImpact: return "applyOpponentImpact"
        case .acknowledgeDestructionAlert: return "acknowledgeDestructionAlert"
        case .restartSetup: return "restartSetup"
        case .confirmSetup: return "confirmSetup"
        case .newGame: return "newGame"
        case .finishPostGameMapReview: return "finishPostGameMapReview"
        case .clearWelcomeStartMenuRequest: return "clearWelcomeStartMenuRequest"
        case .finalizePlayerMissileIntercept: return "finalizePlayerMissileIntercept"
        case .finalizePlayerBomberIntercept: return "finalizePlayerBomberIntercept"
        case .finalizeOpponentMissileIntercept: return "finalizeOpponentMissileIntercept"
        case .finalizeOpponentBomberIntercept: return "finalizeOpponentBomberIntercept"
        }
    }

    private static func actionDetail(_ action: Action) -> [String: String]? {
        switch action {
        case .tap(let p):
            return ["pos": "\(p.row)_\(p.col)"]
        default:
            return nil
        }
    }

    private static func phasePath(_ phase: Phase) -> String {
        switch phase {
        case .welcome: return "welcome"
        case .setup(let step):
            switch step {
            case .placeHeadquarter: return "setup.placeHeadquarter"
            case .placeMissile1: return "setup.placeMissile1"
            case .placeMissile2: return "setup.placeMissile2"
            case .placeBomber: return "setup.placeBomber"
            case .placeCoastguard: return "setup.placeCoastguard"
            }
        case .setupConfirm: return "setupConfirm"
        case .play(let play):
            return "play." + playStatePath(play)
        case .victory: return "victory"
        case .defeat: return "defeat"
        }
    }

    private static func playStatePath(_ play: PlayState) -> String {
        switch play {
        case .idle: return "idle"
        case .shotDown(let w, let attacker):
            return "shotDown.\(weaponPath(w)).\(String(describing: attacker))"
        case .missileInterceptFlight(let src, let anchor):
            return "missileInterceptFlight.\(src.row)_\(src.col).\(anchor.row)_\(anchor.col)"
        case .bomberInterceptFlight(let src, let anchor):
            return "bomberInterceptFlight.\(src.row)_\(src.col).\(anchor.row)_\(anchor.col)"
        case .opponentMissileInterceptFlight(let src, let anchor):
            return "opponentMissileInterceptFlight.\(src.row)_\(src.col).\(anchor.row)_\(anchor.col)"
        case .opponentBomberInterceptFlight(let src, let anchor):
            return "opponentBomberInterceptFlight.\(src.row)_\(src.col).\(anchor.row)_\(anchor.col)"
        case .choosingBombTarget(let src):
            return "choosingBombTarget.\(src.row)_\(src.col)"
        case .bombingDrops(let src, let tgt, let n):
            return "bombingDrops.\(src.row)_\(src.col).\(tgt.row)_\(tgt.col).drops\(n)"
        case .missileFlight(let src, let anchor, let attacker):
            return "missileFlight.\(src.row)_\(src.col).\(anchor.row)_\(anchor.col).\(String(describing: attacker))"
        case .choosingMissileTarget(let src):
            return "choosingMissileTarget.\(src.row)_\(src.col)"
        }
    }

    private static func weaponPath(_ w: Weapon) -> String {
        switch w {
        case .bomber: return "bomber"
        case .missile: return "missile"
        }
    }

    private static func uiModeLabel(_ mode: UIMode) -> String {
        switch mode {
        case .welcome: return "welcome"
        case .setup(let step): return "setup.\(String(describing: step))"
        case .setupConfirm: return "setupConfirm"
        case .play(let play): return "play.\(playStatePath(play))"
        case .destructionAlert: return "destructionAlert"
        case .victory: return "victory"
        case .defeat: return "defeat"
        }
    }

    private static func pendingLabel(_ pending: PendingOpponentImpact?) -> String? {
        guard let pending else { return nil }
        switch pending {
        case .grenade(let target):
            return "grenade.\(target.row)_\(target.col)"
        case .bomber(let source, let target):
            return "bomber.\(source.row)_\(source.col).\(target.row)_\(target.col)"
        }
    }
}

#endif
