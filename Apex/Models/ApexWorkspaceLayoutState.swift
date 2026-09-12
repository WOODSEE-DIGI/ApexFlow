import Foundation
import SwiftUI

// MARK: - Canvas Grid

/// The Apex workspace grid: 12 columns × 8 rows with gutters.
/// Tiles occupy whole cell spans and cannot overlap.
enum ApexCanvasGrid {
    static let cols = 12
    static let rows = 14
    static let gap: Double = 8

    static func cellSize(in canvas: CGSize) -> CGSize {
        CGSize(
            width: (Double(canvas.width) - gap * Double(cols + 1)) / Double(cols),
            height: (Double(canvas.height) - gap * Double(rows + 1)) / Double(rows)
        )
    }

    static func frame(col: Int, row: Int, colSpan: Int, rowSpan: Int, in canvas: CGSize) -> CGRect {
        let cell = cellSize(in: canvas)
        let x = gap + Double(col) * (cell.width + gap)
        let y = gap + Double(row) * (cell.height + gap)
        let w = Double(colSpan) * cell.width + Double(colSpan - 1) * gap
        let h = Double(rowSpan) * cell.height + Double(rowSpan - 1) * gap
        return CGRect(x: x, y: y, width: w, height: h)
    }

    static func cell(at point: CGPoint, in canvas: CGSize) -> (col: Int, row: Int) {
        let cell = cellSize(in: canvas)
        // Round to the nearest cell centre instead of flooring, so tiles snap
        // to the closest grid position rather than always favouring the top/left.
        let col = Int(((Double(point.x) - gap) / (cell.width + gap)).rounded())
        let row = Int(((Double(point.y) - gap) / (cell.height + gap)).rounded())
        return (min(max(0, col), cols - 1), min(max(0, row), rows - 1))
    }

    static func spansIntersect(_ a: (col: Int, row: Int, colSpan: Int, rowSpan: Int),
                               _ b: (col: Int, row: Int, colSpan: Int, rowSpan: Int)) -> Bool {
        a.col < b.col + b.colSpan && b.col < a.col + a.colSpan
            && a.row < b.row + b.rowSpan && b.row < a.row + a.rowSpan
    }
}

// MARK: - Canvas Tile

struct ApexCanvasTile: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var kind: ApexPanelKind
    var col: Int
    var row: Int
    var colSpan: Int
    var rowSpan: Int
    var z: Int

    var cellSpan: (col: Int, row: Int, colSpan: Int, rowSpan: Int) { (col, row, colSpan, rowSpan) }

    func frame(in canvas: CGSize) -> CGRect {
        ApexCanvasGrid.frame(col: col, row: row, colSpan: colSpan, rowSpan: rowSpan, in: canvas)
    }

    var minColSpan: Int {
        let width = kind.minWidth
        return width > 500 ? 7 : width > 400 ? 6 : width > 300 ? 5 : 4
    }
    var minRowSpan: Int { 2 }
}

// MARK: - Workspace Layout State

/// Tracks the tiled workspace for Apex Flow: a single canvas with movable,
/// resizable panels. No floating windows or secondary canvases — just the
/// existing dashboard panels arranged by the user.
@Observable
@MainActor
final class ApexWorkspaceLayoutState {
    static let shared = ApexWorkspaceLayoutState()

    private(set) var tiles: [ApexCanvasTile] = []
    var isLocked = false
    private(set) var savedLayoutNames: [String] = []
    private(set) var currentLayoutName: String? = nil

    private let defaultsKey = "apex.workspace.layout.v2"
    private let savedLayoutsKey = "apex.workspace.savedLayouts.v1"

    init() {
        loadSavedLayoutNames()
        load()
        if tiles.isEmpty {
            resetDefaultLayout()
        }
    }

    // MARK: - Default layout

    func resetDefaultLayout() {
        var z = 0
        func tile(_ kind: ApexPanelKind, col: Int, row: Int, colSpan: Int, rowSpan: Int) -> ApexCanvasTile {
            z += 1
            return ApexCanvasTile(kind: kind, col: col, row: row, colSpan: colSpan, rowSpan: rowSpan, z: z)
        }

        tiles = [
            // Top: full-width CPU graph
            tile(.cpu, col: 0, row: 0, colSpan: 12, rowSpan: 2),
            // Left column
            tile(.network, col: 0, row: 2, colSpan: 6, rowSpan: 3),
            tile(.networkLeak, col: 0, row: 5, colSpan: 6, rowSpan: 4),
            tile(.connectivity, col: 0, row: 9, colSpan: 6, rowSpan: 5),
            // Right column
            tile(.memory, col: 6, row: 2, colSpan: 6, rowSpan: 5),
            tile(.diskHealth, col: 6, row: 7, colSpan: 6, rowSpan: 3),
            tile(.processes, col: 6, row: 10, colSpan: 6, rowSpan: 4)
        ]
        currentLayoutName = nil
        clampTilesToCanvas(CGSize(width: 1200, height: 1000))
        save()
    }

    // MARK: - Queries

    func tile(id: UUID) -> ApexCanvasTile? {
        tiles.first { $0.id == id }
    }

    func tile(containing kind: ApexPanelKind) -> ApexCanvasTile? {
        tiles.first { $0.kind == kind }
    }

    func isOpen(_ kind: ApexPanelKind) -> Bool {
        tiles.contains { $0.kind == kind }
    }

    // MARK: - Open / close

    func open(_ kind: ApexPanelKind) {
        guard !isOpen(kind) else { return }
        guard let spot = bestPlacement(preferred: kind.preferredSpan, minColSpan: minSpan(kind).col, minRowSpan: minSpan(kind).row) else { return }
        tiles.append(ApexCanvasTile(
            kind: kind,
            col: spot.col, row: spot.row,
            colSpan: spot.colSpan, rowSpan: spot.rowSpan,
            z: nextZ()
        ))
        save()
    }

    func close(_ kind: ApexPanelKind) {
        tiles.removeAll { $0.kind == kind }
        save()
    }

    func toggle(_ kind: ApexPanelKind) {
        if isOpen(kind) { close(kind) } else { open(kind) }
    }

    // MARK: - Move / resize

    func moveTile(_ id: UUID, toCol col: Int, row: Int) {
        guard let idx = tiles.firstIndex(where: { $0.id == id }) else { return }
        let span = tiles[idx].cellSpan
        let col = min(max(0, col), ApexCanvasGrid.cols - span.colSpan)
        let row = min(max(0, row), ApexCanvasGrid.rows - span.rowSpan)
        tiles[idx].col = col
        tiles[idx].row = row
        save()
    }

    func resizeTileSpan(_ id: UUID, colSpan: Int, rowSpan: Int) {
        guard let idx = tiles.firstIndex(where: { $0.id == id }) else { return }
        let tile = tiles[idx]
        let newColSpan = max(tile.minColSpan, min(ApexCanvasGrid.cols - tile.col, colSpan))
        let newRowSpan = max(tile.minRowSpan, min(ApexCanvasGrid.rows - tile.row, rowSpan))
        tiles[idx].colSpan = newColSpan
        tiles[idx].rowSpan = newRowSpan
        save()
    }

    func swapTiles(_ idA: UUID, _ idB: UUID) {
        guard let idxA = tiles.firstIndex(where: { $0.id == idA }),
              let idxB = tiles.firstIndex(where: { $0.id == idB }) else { return }
        let a = tiles[idxA]
        let b = tiles[idxB]
        tiles[idxA].col = b.col
        tiles[idxA].row = b.row
        tiles[idxB].col = a.col
        tiles[idxB].row = a.row
        bringTileToFront(idA)
        save()
    }

    func bringTileToFront(_ id: UUID) {
        guard let idx = tiles.firstIndex(where: { $0.id == id }) else { return }
        let maxZ = tiles.map(\.z).max() ?? 0
        tiles[idx].z = maxZ + 1
    }

    func clampTilesToCanvas(_ size: CGSize) {
        for idx in tiles.indices {
            tiles[idx].col = min(tiles[idx].col, ApexCanvasGrid.cols - max(tiles[idx].minColSpan, tiles[idx].colSpan))
            tiles[idx].row = min(tiles[idx].row, ApexCanvasGrid.rows - max(tiles[idx].minRowSpan, tiles[idx].rowSpan))
            tiles[idx].colSpan = min(tiles[idx].colSpan, ApexCanvasGrid.cols - tiles[idx].col)
            tiles[idx].rowSpan = min(tiles[idx].rowSpan, ApexCanvasGrid.rows - tiles[idx].row)
            tiles[idx].col = max(0, tiles[idx].col)
            tiles[idx].row = max(0, tiles[idx].row)
        }
    }

    // MARK: - Placement helpers

    private func minSpan(_ kind: ApexPanelKind) -> (col: Int, row: Int) {
        let tile = ApexCanvasTile(kind: kind, col: 0, row: 0, colSpan: 1, rowSpan: 1, z: 0)
        return (tile.minColSpan, tile.minRowSpan)
    }

    private func nextZ() -> Int {
        (tiles.map(\.z).max() ?? 0) + 1
    }

    private func bestPlacement(preferred: (col: Int, row: Int), minColSpan: Int, minRowSpan: Int) -> (col: Int, row: Int, colSpan: Int, rowSpan: Int)? {
        let colSpan = min(preferred.col, ApexCanvasGrid.cols)
        let rowSpan = min(preferred.row, ApexCanvasGrid.rows)
        // Scan top-left for a free spot that fits the preferred span.
        for row in 0...(ApexCanvasGrid.rows - rowSpan) {
            for col in 0...(ApexCanvasGrid.cols - colSpan) {
                let candidate = (col: col, row: row, colSpan: colSpan, rowSpan: rowSpan)
                if !tiles.contains(where: { ApexCanvasGrid.spansIntersect($0.cellSpan, candidate) }) {
                    return candidate
                }
            }
        }
        // Fall back to the smallest span.
        for row in 0...(ApexCanvasGrid.rows - minRowSpan) {
            for col in 0...(ApexCanvasGrid.cols - minColSpan) {
                let candidate = (col: col, row: row, colSpan: minColSpan, rowSpan: minRowSpan)
                if !tiles.contains(where: { ApexCanvasGrid.spansIntersect($0.cellSpan, candidate) }) {
                    return candidate
                }
            }
        }
        return nil
    }

    // MARK: - Saved layouts

    func saveCurrentLayout(as name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(tiles) else { return }
        var layouts = savedLayoutsDictionary()
        layouts[trimmed] = data
        UserDefaults.standard.set(layouts, forKey: savedLayoutsKey)
        loadSavedLayoutNames()
        currentLayoutName = trimmed
    }

    func loadLayout(named name: String) {
        let layouts = savedLayoutsDictionary()
        guard let data = layouts[name],
              let decoded = try? JSONDecoder().decode([ApexCanvasTile].self, from: data)
        else { return }
        tiles = decoded
        currentLayoutName = name
        save()
    }

    func deleteLayout(named name: String) {
        var layouts = savedLayoutsDictionary()
        layouts.removeValue(forKey: name)
        UserDefaults.standard.set(layouts, forKey: savedLayoutsKey)
        loadSavedLayoutNames()
        if currentLayoutName == name {
            currentLayoutName = nil
        }
    }

    private func savedLayoutsDictionary() -> [String: Data] {
        (UserDefaults.standard.object(forKey: savedLayoutsKey) as? [String: Data]) ?? [:]
    }

    private func loadSavedLayoutNames() {
        savedLayoutNames = Array(savedLayoutsDictionary().keys).sorted()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(tiles) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ApexCanvasTile].self, from: data)
        else { return }
        tiles = decoded
    }
}
