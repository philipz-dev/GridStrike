//
//  Unit.swift
//  GridStrike Watch App
//
//  Game pieces and their derived metadata. Pure domain — no SwiftUI imports.
//

import Foundation

enum Unit: Equatable, CaseIterable {
    case headquarters
    case missile
    case bomber
    case coastguard

    var symbol: String {
        switch self {
        case .headquarters: return "X"
        case .missile: return "M"
        case .bomber: return "B"
        case .coastguard: return "C"
        }
    }

    /// Lower-case singular noun used inside aggregated destruction sentences,
    /// e.g. "missile" in "Missile and bomber destroyed!".
    var singularName: String {
        switch self {
        case .headquarters: return "headquarters"
        case .missile: return "missile"
        case .bomber: return "bomber"
        case .coastguard: return "coastguard"
        }
    }

    /// Lower-case plural noun used when the same unit type was destroyed
    /// multiple times in a single attack, e.g. "2 missiles destroyed!".
    /// "Headquarters" reads the same in singular and plural — kept identical
    /// so a (theoretical) double-HQ kill still looks grammatical.
    var pluralName: String {
        switch self {
        case .headquarters: return "headquarters"
        case .missile: return "missiles"
        case .bomber: return "bombers"
        case .coastguard: return "coastguards"
        }
    }
}

extension Array where Element == Unit {
    /// Sentence-cased message describing every unit destroyed in a single
    /// attack, phrased from the perspective of the attacker so the player
    /// gets the right "us vs them" framing.
    ///
    /// Player-driven attacks (you hit the enemy):
    ///   `[.missile]`                          → "Enemy missile destroyed!"
    ///   `[.missile, .missile]`                → "2 enemy missiles destroyed!"
    ///   `[.headquarters, .bomber, .missile]`  → "Enemy's headquarters, bomber and missile destroyed!"
    ///   `[.missile, .missile, .bomber]`       → "2 enemy missiles and bomber destroyed!"
    ///   `[.bomber, .missile, .missile]`       → "Enemy bomber and 2 missiles destroyed!"
    ///
    /// Opponent-driven attacks (the AI hit you):
    ///   `[.missile]`                          → "Your missile is destroyed!"
    ///   `[.missile, .missile]`                → "Your 2 missiles are destroyed!"
    ///   `[.headquarters, .bomber, .missile]`  → "Your headquarters, bomber and missile are destroyed!"
    ///   `[.missile, .missile, .bomber]`       → "Your 2 missiles and bomber are destroyed!"
    ///
    /// Empty arrays return an empty string — callers should avoid queuing
    /// alerts in that case.
    func destroyedAlertMessage(attacker: Side) -> String {
        // Group by unit type, preserving the order each type was first hit
        // so the sentence reads in the same order the units were destroyed.
        var counts: [(unit: Unit, count: Int)] = []
        for u in self {
            if let i = counts.firstIndex(where: { $0.unit == u }) {
                counts[i].count += 1
            } else {
                counts.append((u, 1))
            }
        }
        if counts.isEmpty { return "" }

        // Per-group phrase: bare singular for count 1, "<count> <plural>" otherwise.
        let phrases = counts.map { entry -> String in
            entry.count == 1 ? entry.unit.singularName : "\(entry.count) \(entry.unit.pluralName)"
        }
        // Comma + "and" join — used directly for opponent attacks and for the
        // "Enemy's …" form when every group is a singleton.
        let listed = joinedWithComma(phrases)
        let onlySingleGroup = phrases.count == 1
        let everyGroupSingleton = counts.allSatisfy { $0.count == 1 }

        switch attacker {
        case .player:
            // We hit them — phrase as "Enemy …" / "<n> enemy …" / "Enemy's …".
            if onlySingleGroup {
                let only = counts[0]
                if only.count == 1 {
                    return "Enemy \(only.unit.singularName) destroyed!"
                } else {
                    return "\(only.count) enemy \(only.unit.pluralName) destroyed!"
                }
            }
            if everyGroupSingleton {
                // 2+ distinct singletons — use possessive "Enemy's <a>, <b> and <c>".
                return "Enemy's \(listed) destroyed!"
            }
            // Mixed (at least one multi-count group) — splice "enemy" into the
            // first group's phrase and let the rest follow as plain nouns.
            let first = counts[0]
            let firstWithEnemy: String
            if first.count == 1 {
                firstWithEnemy = "Enemy \(first.unit.singularName)"
            } else {
                firstWithEnemy = "\(first.count) enemy \(first.unit.pluralName)"
            }
            // Explicit `Array<String>` — inside this `Array where Element == Unit`
            // extension, plain `Array(…)` resolves to `[Unit]` and won't accept
            // a `String` slice.
            let tail = Array<String>(phrases.dropFirst())
            return "\(firstWithEnemy)\(joinTailWithComma(tail)) destroyed!"

        case .opponent:
            // They hit us — phrase as "Your … is/are destroyed!". Verb is "is"
            // only when there's a single singular group, "are" otherwise (two
            // missiles, mixed groups, or three singletons all read as plural).
            let verb = (onlySingleGroup && counts[0].count == 1) ? "is" : "are"
            return "Your \(listed) \(verb) destroyed!"
        }
    }

    // MARK: - Internals

    /// Joins a list of noun phrases with English-style comma + "and":
    /// `[a]` → `"a"`, `[a, b]` → `"a and b"`, `[a, b, c]` → `"a, b and c"`.
    private func joinedWithComma(_ phrases: [String]) -> String {
        switch phrases.count {
        case 0: return ""
        case 1: return phrases[0]
        case 2: return "\(phrases[0]) and \(phrases[1])"
        default:
            let head = phrases.dropLast().joined(separator: ", ")
            return "\(head) and \(phrases.last!)"
        }
    }

    /// Variant for "splice into the first phrase" formatting — returns the
    /// suffix that follows an already-rendered first phrase. Empty if `tail`
    /// is empty, otherwise leads with " and " or ", … and …" as appropriate.
    private func joinTailWithComma(_ tail: [String]) -> String {
        switch tail.count {
        case 0: return ""
        case 1: return " and \(tail[0])"
        default:
            let head = tail.dropLast().joined(separator: ", ")
            return ", \(head) and \(tail.last!)"
        }
    }
}

/// Player-launched weapons that the enemy coastguard can intercept.
enum Weapon: Equatable {
    case bomber
    case missile

    var shotDownText: String {
        switch self {
        case .bomber: return "Bomber shot down by enemy coastguard!"
        case .missile: return "Missile shot down by enemy coastguard!"
        }
    }
}

/// Strike result on a tile (used for grenade taps and bombing/missile drops).
enum ExplosionKind: Equatable {
    case hit
    case miss
}

/// Sunk attacker overlay rendered on the row south of the enemy coastguard.
enum WaterWreck: Equatable {
    case plane
    case missile
}
