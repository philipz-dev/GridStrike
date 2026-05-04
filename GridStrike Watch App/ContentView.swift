//
//  ContentView.swift
//  GridStrike Watch App
//

import SwiftUI

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

private struct GridStrikeFlowView: View {
    @State private var phase: SetupPhase = .welcome
    @State private var cellMarks: [String: UnitMark] = [:]

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
                onCellTap: handleCellTap
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Text must not use frame(maxWidth: .infinity) alone in a full-height overlay —
            // SwiftUI vertically centers multiline labels. Pin with VStack + Spacer instead.
            VStack(spacing: 0) {
                Text(instructionText)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
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
        }
    }

    private var instructionText: String {
        switch phase {
        case .welcome: ""
        case .placeHeadquarter: "Place headquarter"
        case .placeMissile1: "Place missile 1"
        case .placeMissile2: "Place missile 2"
        case .placeBomber: "Place bomber"
        case .placeCoastguard: "Place coastguard"
        case .complete: "Setup complete"
        }
    }

    private func cellKey(_ row: Int, _ col: Int) -> String {
        "\(row)_\(col)"
    }

    private func mark(at row: Int, _ col: Int) -> UnitMark? {
        cellMarks[cellKey(row, col)]
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
}

// MARK: - Scroll notification (watchOS-friendly)

private extension Notification.Name {
    static let gridStrikeScrollToCoastguard = Notification.Name("gridStrikeScrollToCoastguard")
}

// MARK: - Grid

private struct GridStrikeSetupGrid: View {
    /// Water rows are 5…8 (top→bottom). Coastguard is placed on **row 8** (southern water, next to bottom grass).
    fileprivate static let coastguardWaterRowIndex = 8

    let phase: SetupPhase
    let cellMarks: [String: UnitMark]
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
    /// Otherwise: empty non-playable tiles ghosted; occupied tiles full color.
    private func isVisuallyGhosted(row: Int, col: Int) -> Bool {
        guard phase != .complete else { return false }

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
        let dimmed = phase == .complete ? false : isVisuallyGhosted(row: row, col: col)
        /// Every tile off the coastguard row while placing it (including occupied grass).
        let offCoastguardFocusRow = phase == .placeCoastguard && row != Self.coastguardWaterRowIndex
        let coastguardOffRowGhost = dimmed && phase == .placeCoastguard
        let selectable = isSelectable(row: row, col: col)
        let mark = mark(at: row, col)
        let fontSize = min(width, height) * 0.42

        return Button {
            onCellTap(row, col)
        } label: {
            ZStack {
                Image(tileBackgroundImageName(water: water, mark: mark))
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
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

                Rectangle()
                    .strokeBorder(
                        dimmed ? Color.black.opacity(coastguardOffRowGhost ? 0.5 : 0.42) : Color.black,
                        lineWidth: dimmed ? 1.5 : 2
                    )
            }
            .compositingGroup()
            .opacity(offCoastguardFocusRow ? 0.88 : 1)
            .frame(width: width, height: height)
            .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
        // watchOS dims disabled buttons. Only disable empty non-playable cells; occupied cells
        // stay enabled so they don’t look ghosted — taps still no-op in handleCellTap.
        .disabled(phase != .complete && mark == nil && !selectable)
    }
}

#Preview {
    ContentView()
}
