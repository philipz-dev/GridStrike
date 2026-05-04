//
//  ContentView.swift
//  GridStrike Watch App
//

import SwiftUI
import WatchKit

struct ContentView: View {
    var body: some View {
        GridStrikeFlowView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Flow

private enum SetupPhase: Equatable {
    case welcome
    case placeHeadquarter
    case placeMissile1
    case placeMissile2
    case placeBomber
    case placeCoastguard
    case complete
}

private enum UnitMark: Equatable {
    case headquarters
    case missile
    case bomber
    case coastguard

    var symbol: String {
        switch self {
        case .headquarters: "X"
        case .missile: "M"
        case .bomber: "B"
        case .coastguard: "C"
        }
    }
}

private enum NorthernPlayfieldStrike: Equatable {
    /// Unit present (HQ / missile / bomber).
    case hit
    /// Empty northern grass.
    case miss
}

private enum BombingDropOverlay: Equatable {
    /// Unit on the tile — colored `explosion` asset.
    case onUnit
    /// Empty grass — `explosion_black` asset.
    case onGrass
}

private struct GridStrikeFlowView: View {
    @State private var phase: SetupPhase = .welcome
    @State private var cellMarks: [String: UnitMark] = [:]
    /// Degrees; only spawned post-setup bomber uses 180.
    @State private var bomberRotationDegreesByKey: [String: Double] = [:]
    @State private var didApplyPostSetupSpawn = false
    @State private var northernPlayfieldStrikes: [String: NorthernPlayfieldStrike] = [:]
    @State private var bombingRunActive = false
    @State private var bombingChoosingTarget = false
    @State private var bombingSourceKey: String?
    @State private var bombingDropOverlays: [String: BombingDropOverlay] = [:]
    /// Northern water tile (row 6) showing downed bomber; same column as coastguard when shot down.
    @State private var planeInWaterTileKey: String?
    @State private var bomberShotDownInstruction: String?

    @State private var missileRunActive = false
    @State private var missileChoosingTarget = false
    @State private var missileSourceKey: String?
    @State private var missileStrikeOverlays: [String: BombingDropOverlay] = [:]
    @State private var missileInWaterTileKey: String?
    @State private var missileShotDownInstruction: String?

    var body: some View {
        Group {
            if phase == .welcome {
                welcomeScreen
            } else {
                setupGridContainer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeScreen: some View {
        ZStack(alignment: .bottom) {
            Image("SplashBackground")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, minHeight: 0)
                .clipped()
                .ignoresSafeArea()
            Color.black.opacity(0.42)
                .ignoresSafeArea()
            Text("Welcome to GridStrike!")
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 6, y: 2)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            phase = .placeHeadquarter
        }
    }

    private var setupGridContainer: some View {
        ZStack(alignment: .topLeading) {
            GridStrikeSetupGrid(
                phase: phase,
                cellMarks: cellMarks,
                bomberRotationDegreesByKey: bomberRotationDegreesByKey,
                northernPlayfieldStrikes: northernPlayfieldStrikes,
                bombingRunActive: bombingRunActive,
                bombingChoosingTarget: bombingChoosingTarget,
                bombingSourceKey: bombingSourceKey,
                bombingDropOverlays: bombingDropOverlays,
                planeInWaterTileKey: planeInWaterTileKey,
                missileRunActive: missileRunActive,
                missileChoosingTarget: missileChoosingTarget,
                missileSourceKey: missileSourceKey,
                missileStrikeOverlays: missileStrikeOverlays,
                missileInWaterTileKey: missileInWaterTileKey,
                onCellTap: handleCellTap
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Text must not use frame(maxWidth: .infinity) alone in a full-height overlay —
            // SwiftUI vertically centers multiline labels. Pin with VStack + Spacer instead.
            VStack(spacing: 0) {
                Text(instructionText)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.92), radius: 4, y: 2)
                    .shadow(color: .black.opacity(0.55), radius: 1, y: 0)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
                    .offset(y: -15)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: phase) { _, newPhase in
            if newPhase == .placeCoastguard {
                NotificationCenter.default.post(name: .gridStrikeScrollToCoastguard, object: nil)
            }
            if newPhase == .complete {
                applyPostSetupSpawnIfNeeded()
            }
        }
    }

    private var instructionText: String {
        if bombingRunActive && bombingChoosingTarget {
            return "Define bombing area!"
        }
        if missileRunActive && missileChoosingTarget {
            return "Define missile strike!"
        }
        if phase == .complete, let shotDown = missileShotDownInstruction {
            return shotDown
        }
        if phase == .complete, let shotDown = bomberShotDownInstruction {
            return shotDown
        }
        if bombingRunActive {
            return ""
        }
        switch phase {
        case .welcome: return ""
        case .placeHeadquarter: return "Place headquarter"
        case .placeMissile1: return "Place missile 1"
        case .placeMissile2: return "Place missile 2"
        case .placeBomber: return "Place bomber"
        case .placeCoastguard: return "Place coastguard"
        case .complete: return "Setup complete"
        }
    }

    private func cellKey(_ row: Int, _ col: Int) -> String {
        "\(row)_\(col)"
    }

    private func mark(at row: Int, _ col: Int) -> UnitMark? {
        cellMarks[cellKey(row, col)]
    }

    /// Post-setup coastguard lives on northern water (`postSetupCoastguardRowIndex`).
    private func northernCoastguardColumn() -> Int? {
        let r = GridStrikeSetupGrid.postSetupCoastguardRowIndex
        for c in 0..<5 where mark(at: r, c) == .coastguard {
            return c
        }
        return nil
    }

    /// True when the vertical three-drop path shares the coastguard column and at least one cell is north of row-5 water (above the cruiser).
    private func bombingPathCrossesAboveNorthernCoastguard(startRow: Int, col: Int) -> Bool {
        guard let coastCol = northernCoastguardColumn(), coastCol == col else { return false }
        let coastWaterRow = GridStrikeSetupGrid.postSetupCoastguardRowIndex
        for i in 0..<3 {
            let r = startRow - i
            if r >= 0 && r < coastWaterRow { return true }
        }
        return false
    }

    /// 2×2 square (lower-left `r`,`c`) spans columns `c` and `c+1`; shot down if coastguard column is either.
    private func missileSquareCrossesNorthernCoastguard(lowerLeftRow r: Int, col c: Int) -> Bool {
        guard let coastCol = northernCoastguardColumn() else { return false }
        return coastCol == c || coastCol == c + 1
    }

    /// After bombing or shoot-down, the southern bomber tile (rows 9–13) becomes empty grass.
    private func replaceSouthernBomberWithGrassIfNeeded(bomberTileKey: String?) {
        guard let key = bomberTileKey else { return }
        guard let rowString = key.split(separator: "_").first, let row = Int(rowString) else { return }
        guard row >= 9 && row <= 13 else { return }
        guard cellMarks[key] == .bomber else { return }
        cellMarks.removeValue(forKey: key)
        bomberRotationDegreesByKey.removeValue(forKey: key)
    }

    /// After missile strike or shoot-down, the southern missile tile (rows 9–13) becomes empty grass.
    private func replaceSouthernMissileWithGrassIfNeeded(missileTileKey: String?) {
        guard let key = missileTileKey else { return }
        guard let rowString = key.split(separator: "_").first, let row = Int(rowString) else { return }
        guard row >= 9 && row <= 13 else { return }
        guard cellMarks[key] == .missile else { return }
        cellMarks.removeValue(forKey: key)
    }

    private func isSelectable(row: Int, col: Int) -> Bool {
        if mark(at: row, col) != nil { return false }
        switch phase {
        case .placeHeadquarter:
            return Self.isBottomGrassRow(row)
        case .placeMissile1, .placeMissile2, .placeBomber:
            return Self.isGrass(row)
        case .placeCoastguard:
            return row == GridStrikeSetupGrid.coastguardWaterRowIndex
        default:
            return false
        }
    }

    private func handleCellTap(row: Int, col: Int) {
        if phase == .complete {
            let key = cellKey(row, col)
            let m = mark(at: row, col)

            if !bombingRunActive, !missileRunActive, row >= 9 && row <= 13, m == .bomber {
                bomberShotDownInstruction = nil
                bombingRunActive = true
                bombingChoosingTarget = true
                bombingSourceKey = key
                return
            }

            if !bombingRunActive, !missileRunActive, row >= 9 && row <= 13, m == .missile {
                missileShotDownInstruction = nil
                missileRunActive = true
                missileChoosingTarget = true
                missileSourceKey = key
                return
            }

            if bombingRunActive && bombingChoosingTarget {
                guard row >= 2 && row <= 4, col >= 0 && col < 5 else { return }
                bombingChoosingTarget = false
                runBombingDropSequence(startRow: row, col: col)
                return
            }

            if missileRunActive && missileChoosingTarget {
                guard row >= 1 && row <= 4, col >= 0 && col <= 3 else { return }
                missileChoosingTarget = false
                runMissileStrikeSequence(lowerLeftRow: row, col: col)
                return
            }

            // Drops in progress: ignore all taps (buttons stay enabled so watchOS does not dim the grid).
            if bombingRunActive { return }

            guard row >= 0 && row < 5, col >= 0 && col < 5 else { return }
            guard northernPlayfieldStrikes[key] == nil else { return }
            let hasStrikeableUnit = m == .headquarters || m == .missile || m == .bomber
            northernPlayfieldStrikes[key] = hasStrikeableUnit ? .hit : .miss
            WKInterfaceDevice.current().play(.notification)
            return
        }
        guard isSelectable(row: row, col: col) else { return }
        let key = cellKey(row, col)
        switch phase {
        case .placeHeadquarter:
            cellMarks[key] = .headquarters
            phase = .placeMissile1
        case .placeMissile1:
            cellMarks[key] = .missile
            phase = .placeMissile2
        case .placeMissile2:
            cellMarks[key] = .missile
            phase = .placeBomber
        case .placeBomber:
            cellMarks[key] = .bomber
            phase = .placeCoastguard
        case .placeCoastguard:
            cellMarks[key] = .coastguard
            phase = .complete
        default:
            break
        }
    }

    /// Rows 9…13 — southern grass (bottom band of 5 rows).
    private static func isBottomGrassRow(_ row: Int) -> Bool {
        row >= 9 && row <= 13
    }

    /// Rows 0…4 and 9…13 — all grass.
    private static func isGrass(_ row: Int) -> Bool {
        row <= 4 || row >= 9
    }

    /// Northern grass rows 0–4: random HQ, 2 missiles, bomber (bomber 180°). Water row 5: coastguard in HQ or bomber column.
    private func applyPostSetupSpawnIfNeeded() {
        guard !didApplyPostSetupSpawn else { return }

        var emptyNorthern: [(Int, Int)] = []
        for row in 0..<5 {
            for col in 0..<5 {
                let k = cellKey(row, col)
                if cellMarks[k] == nil {
                    emptyNorthern.append((row, col))
                }
            }
        }
        guard emptyNorthern.count >= 4 else { return }
        didApplyPostSetupSpawn = true

        emptyNorthern.shuffle()
        let picked = Array(emptyNorthern.prefix(4))
        var units: [UnitMark] = [.headquarters, .missile, .missile, .bomber]
        units.shuffle()

        var hqColumn: Int?
        var bomberColumn: Int?
        for i in 0..<4 {
            let (row, col) = picked[i]
            let unit = units[i]
            let key = cellKey(row, col)
            cellMarks[key] = unit
            if unit == .headquarters { hqColumn = col }
            if unit == .bomber {
                bomberColumn = col
                bomberRotationDegreesByKey[key] = 180
            }
        }

        let coastColumns = Set([hqColumn, bomberColumn].compactMap { $0 })
        guard let coastCol = coastColumns.randomElement() else { return }
        let coastRow = GridStrikeSetupGrid.postSetupCoastguardRowIndex
        let coastKey = cellKey(coastRow, coastCol)
        if cellMarks[coastKey] == nil {
            cellMarks[coastKey] = .coastguard
        }
    }

    /// Three cells northward from the chosen row; 1s between each overlay. Unit → colored explosion, empty grass → black.
    /// Shot down: no explosion overlays; only message + plane on coastguard tile.
    private func runBombingDropSequence(startRow: Int, col: Int) {
        let sourceKey = bombingSourceKey
        if bombingPathCrossesAboveNorthernCoastguard(startRow: startRow, col: col) {
            bomberShotDownInstruction = "Bomber shot down by enemy coastguard!"
            planeInWaterTileKey = cellKey(GridStrikeSetupGrid.planeInWaterRowIndex, col)
            replaceSouthernBomberWithGrassIfNeeded(bomberTileKey: sourceKey)
            bombingRunActive = false
            bombingChoosingTarget = false
            bombingSourceKey = nil
            return
        }
        Task { @MainActor in
            for i in 0..<3 {
                let r = startRow - i
                guard r >= 0 else { continue }
                let k = cellKey(r, col)
                if cellMarks[k] != nil {
                    bombingDropOverlays[k] = .onUnit
                } else {
                    bombingDropOverlays[k] = .onGrass
                }
                WKInterfaceDevice.current().play(.notification)
                if i < 2 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            replaceSouthernBomberWithGrassIfNeeded(bomberTileKey: sourceKey)
            bombingRunActive = false
            bombingChoosingTarget = false
            bombingSourceKey = nil
        }
    }

    /// 2×2 from lower-left `(r,c)` — cells `(r,c)`, `(r,c+1)`, `(r-1,c)`, `(r-1,c+1)`. Overlays apply together; no delay.
    /// Shot down: no strike overlays; message + `MissileInWater` on row 6 (lower-left column).
    private func runMissileStrikeSequence(lowerLeftRow r: Int, col c: Int) {
        let sourceKey = missileSourceKey
        if missileSquareCrossesNorthernCoastguard(lowerLeftRow: r, col: c) {
            missileShotDownInstruction = "Missile shot down by enemy coastguard!"
            missileInWaterTileKey = cellKey(GridStrikeSetupGrid.planeInWaterRowIndex, c)
            replaceSouthernMissileWithGrassIfNeeded(missileTileKey: sourceKey)
            missileRunActive = false
            missileChoosingTarget = false
            missileSourceKey = nil
            return
        }
        let cells = [(r, c), (r, c + 1), (r - 1, c), (r - 1, c + 1)]
        for (rr, cc) in cells {
            let k = cellKey(rr, cc)
            missileStrikeOverlays[k] = cellMarks[k] != nil ? .onUnit : .onGrass
        }
        WKInterfaceDevice.current().play(.notification)
        replaceSouthernMissileWithGrassIfNeeded(missileTileKey: sourceKey)
        missileRunActive = false
        missileChoosingTarget = false
        missileSourceKey = nil
    }
}

// MARK: - Scroll notification (watchOS-friendly)

private extension Notification.Name {
    static let gridStrikeScrollToCoastguard = Notification.Name("gridStrikeScrollToCoastguard")
}

// MARK: - Grid

private struct GridStrikeSetupGrid: View {
    /// Water rows are 5…8 (top→bottom). Coastguard is placed on **row 8** (southern water, next to bottom grass).
    fileprivate static let coastguardWaterRowIndex = 8
    /// Extra coastguard after setup (northern water, adjacent to top grass).
    fileprivate static let postSetupCoastguardRowIndex = 5
    /// `PlaneInWater` overlay sits one water row south of the coastguard (row 5).
    fileprivate static let planeInWaterRowIndex = 6

    let phase: SetupPhase
    let cellMarks: [String: UnitMark]
    let bomberRotationDegreesByKey: [String: Double]
    let northernPlayfieldStrikes: [String: NorthernPlayfieldStrike]
    let bombingRunActive: Bool
    let bombingChoosingTarget: Bool
    let bombingSourceKey: String?
    let bombingDropOverlays: [String: BombingDropOverlay]
    let planeInWaterTileKey: String?
    let missileRunActive: Bool
    let missileChoosingTarget: Bool
    let missileSourceKey: String?
    let missileStrikeOverlays: [String: BombingDropOverlay]
    let missileInWaterTileKey: String?
    let onCellTap: (Int, Int) -> Void

    private static let columns = 5
    private static let rows = 14
    private static let bottomCurveTapReserve: CGFloat = 10

    @State private var didInitialScroll = false

    private var bottomRowScrollId: String {
        "row-\(Self.rows - 1)"
    }

    var body: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 2
            let tileWidth = max(1, (geo.size.width - horizontalPadding * 2) / CGFloat(Self.columns))
            let tileHeight = tileWidth
            let bottomInset = geo.safeAreaInsets.bottom
            let pullDown = max(0, bottomInset - Self.bottomCurveTapReserve)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(0..<Self.rows, id: \.self) { row in
                            rowView(row: row, tileWidth: tileWidth, tileHeight: tileHeight)
                                .id("row-\(row)")
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, -pullDown)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                .onAppear {
                    guard !didInitialScroll else { return }
                    didInitialScroll = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        proxy.scrollTo(bottomRowScrollId, anchor: .bottom)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .gridStrikeScrollToCoastguard)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        proxy.scrollTo("row-\(Self.coastguardWaterRowIndex)", anchor: .center)
                    }
                }
            }
        }
    }

    private func rowView(row: Int, tileWidth: CGFloat, tileHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.columns, id: \.self) { col in
                tileView(row: row, column: col, width: tileWidth, height: tileHeight)
            }
        }
        .frame(height: tileHeight)
    }

    private func cellKey(_ row: Int, _ col: Int) -> String {
        "\(row)_\(col)"
    }

    private func mark(at row: Int, _ col: Int) -> UnitMark? {
        cellMarks[cellKey(row, col)]
    }

    private func isWaterTile(row: Int) -> Bool {
        row >= 5 && row <= 8
    }

    private func isSelectable(row: Int, col: Int) -> Bool {
        if mark(at: row, col) != nil { return false }
        switch phase {
        case .placeHeadquarter:
            return row >= 9 && row <= 13
        case .placeMissile1, .placeMissile2, .placeBomber:
            return row <= 4 || row >= 9
        case .placeCoastguard:
            return row == Self.coastguardWaterRowIndex
        default:
            return false
        }
    }

    /// During coastguard placement, only that water row is full color; all other tiles are ghosted.
    /// When complete + choosing bombing band: only rows 2–4 (+ bomber) are full color.
    /// When complete + choosing missile: only rows 1–4 cols 0–3 (+ southern missile) — ghost top row, col 4, rows 5–13.
    /// After the bombing start tile is chosen (`!bombingChoosingTarget`), all tiles stay full color (including during drops).
    /// Otherwise: empty non-playable tiles ghosted; occupied tiles full color.
    private func isVisuallyGhosted(row: Int, col: Int) -> Bool {
        if phase == .complete {
            if bombingRunActive && bombingChoosingTarget {
                if let bk = bombingSourceKey, cellKey(row, col) == bk { return false }
                return row < 2 || row > 4
            }
            if missileRunActive && missileChoosingTarget {
                if let mk = missileSourceKey, cellKey(row, col) == mk { return false }
                return col == Self.columns - 1 || row == 0 || row >= 5
            }
            // Bombing drops, shot-down, or idle complete: no ghosting anywhere.
            return false
        }

        if phase == .placeCoastguard {
            return row != Self.coastguardWaterRowIndex
        }

        if mark(at: row, col) != nil { return false }
        return !isSelectable(row: row, col: col)
    }

    private func tileBackgroundImageName(water: Bool, mark: UnitMark?) -> String {
        switch mark {
        case .headquarters:
            return "HeadquarterTile"
        case .missile:
            return "MissileTile"
        case .bomber:
            return "BomberTile"
        case .coastguard:
            return "CruiserTile"
        case nil:
            break
        }
        return water ? "water" : "grass"
    }

    private func tileView(row: Int, column col: Int, width: CGFloat, height: CGFloat) -> some View {
        let water = isWaterTile(row: row)
        let dimmed = isVisuallyGhosted(row: row, col: col)
        /// Every tile off the coastguard row while placing it (including occupied grass).
        let offCoastguardFocusRow = phase == .placeCoastguard && row != Self.coastguardWaterRowIndex
        let coastguardOffRowGhost = dimmed && phase == .placeCoastguard
        let selectable = isSelectable(row: row, col: col)
        let mark = mark(at: row, col)
        let bomberRotation = bomberRotationDegreesByKey[cellKey(row, col)] ?? 0
        let fontSize = min(width, height) * 0.42
        let key = cellKey(row, col)
        // Complete phase: never disable (watchOS dims disabled buttons). `handleCellTap` ignores irrelevant taps.
        let buttonDisabled: Bool = {
            if phase == .complete {
                if missileRunActive && missileChoosingTarget {
                    if row >= 1 && row <= 4 && col >= 0 && col <= 3 { return false }
                    if let mk = missileSourceKey, mk == key { return false }
                    return true
                }
                if bombingRunActive && bombingChoosingTarget {
                    if row >= 2 && row <= 4 { return false }
                    if let bk = bombingSourceKey, bk == key { return false }
                    return true
                }
                return false
            }
            return mark == nil && !selectable
        }()

        return Button {
            onCellTap(row, col)
        } label: {
            ZStack {
                Image(tileBackgroundImageName(water: water, mark: mark))
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .rotationEffect(.degrees(mark == .bomber ? bomberRotation : 0))
                    .saturation(offCoastguardFocusRow ? 1 : (coastguardOffRowGhost ? 0.88 : 1))
                    .brightness(dimmed && !offCoastguardFocusRow ? (coastguardOffRowGhost ? -0.04 : 0.05) : 0)
                    .opacity(dimmed && !offCoastguardFocusRow ? (coastguardOffRowGhost ? 0.86 : 0.99) : 1)

                if dimmed && !offCoastguardFocusRow {
                    Color.white.opacity(coastguardOffRowGhost ? 0.16 : 0.08)
                }

                // watchOS often ignores subtle Image opacity on enabled Buttons; scrim + flatten fixes occupied unit tiles.
                if offCoastguardFocusRow {
                    Color.black.opacity(0.32)
                }

                if let mark, mark != .missile, mark != .headquarters, mark != .bomber, mark != .coastguard {
                    Text(mark.symbol)
                        .font(.system(size: fontSize, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.95), radius: 2, y: 1)
                }

                if phase == .complete, row < 5, let strike = northernPlayfieldStrikes[key] {
                    Image(strike == .hit ? "ExplosionHit" : "ExplosionMiss")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: width * 0.92, height: height * 0.92)
                        .allowsHitTesting(false)
                }

                if phase == .complete, let drop = bombingDropOverlays[key] ?? missileStrikeOverlays[key] {
                    Image(drop == .onUnit ? "ExplosionHit" : "ExplosionMiss")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: width * 0.92, height: height * 0.92)
                        .allowsHitTesting(false)
                }

                if phase == .complete, planeInWaterTileKey == key {
                    Image("PlaneInWater")
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: width * 0.88, height: height * 0.88)
                        .foregroundStyle(Color(red: 0.34, green: 0.34, blue: 0.36))
                        .rotationEffect(.degrees(45))
                        .allowsHitTesting(false)
                }

                if phase == .complete, missileInWaterTileKey == key {
                    Image("MissileInWater")
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: width * 0.88, height: height * 0.88)
                        .foregroundStyle(Color(red: 0.34, green: 0.34, blue: 0.36))
                        .rotationEffect(.degrees(45))
                        .allowsHitTesting(false)
                }

                Rectangle()
                    .strokeBorder(
                        (bombingChoosingTarget && bombingSourceKey == key)
                            || (missileChoosingTarget && missileSourceKey == key)
                            ? Color.red
                            : (dimmed ? Color.black.opacity(coastguardOffRowGhost ? 0.5 : 0.42) : Color.black),
                        lineWidth: (bombingChoosingTarget && bombingSourceKey == key)
                            || (missileChoosingTarget && missileSourceKey == key)
                            ? 2.5 : (dimmed ? 1.5 : 2)
                    )
            }
            .compositingGroup()
            .opacity(offCoastguardFocusRow ? 0.88 : 1)
            .frame(width: width, height: height)
            .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
        // watchOS dims disabled buttons. When complete: playfield rows 0–4 + southern missiles/bombers stay enabled (full color); rest dimmed.
        .disabled(buttonDisabled)
    }
}

#Preview {
    ContentView()
}
