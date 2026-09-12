import SwiftUI

// MARK: - Canvas Coordinate Space

enum ApexCanvasCoordinateSpace {
    static let name = "apexCanvas"
}

// MARK: - Canvas Drag State

@Observable
@MainActor
final class ApexCanvasDragState {
    static let shared = ApexCanvasDragState()

    var movingTileID: UUID?
    var resizingTileID: UUID?
    var resizeAnchor: ResizeAnchor = .bottomTrailing
    var dragTranslation: CGSize = .zero
    var resizeDelta: CGSize = .zero
    var pointer: CGPoint = .zero

    enum ResizeAnchor {
        case bottomTrailing
        case topLeading
    }

    private init() {}
}

// MARK: - Canvas Workspace View

struct ApexCanvasWorkspaceView: View {
    let monitor: SystemMonitor

    @State private var layout = ApexWorkspaceLayoutState.shared
    @State private var canvasDrag = ApexCanvasDragState.shared
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                gridBackground(in: geometry.size)

                if layout.tiles.isEmpty {
                    ContentUnavailableView(
                        "No Panels",
                        systemImage: "rectangle.split.2x2",
                        description: Text("Open panels from the toolbar to build your dashboard")
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                ForEach(layout.tiles.sorted(by: { $0.z < $1.z })) { tile in
                    ApexCanvasTileView(tileID: tile.id, canvasSize: geometry.size, monitor: monitor)
                }

                if let ghost = moveGhostRect(in: geometry.size) {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundStyle(theme.accent.opacity(0.7))
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.accent.opacity(0.06))
                        )
                        .frame(width: ghost.width, height: ghost.height)
                        .position(x: ghost.midX, y: ghost.minY + ghost.height / 2)
                        .allowsHitTesting(false)
                        .animation(.linear(duration: 0.06), value: ghost)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .coordinateSpace(name: ApexCanvasCoordinateSpace.name)
            .onAppear { layout.clampTilesToCanvas(geometry.size) }
            .onChange(of: geometry.size) { _, newSize in
                layout.clampTilesToCanvas(newSize)
            }
        }
        .background(theme.base)
    }

    private func gridBackground(in size: CGSize) -> some View {
        Canvas { context, _ in
            let cell = ApexCanvasGrid.cellSize(in: size)
            let dotColor = theme.text.opacity(0.04)
            var x = ApexCanvasGrid.gap
            while x < size.width {
                var y = ApexCanvasGrid.gap
                while y < size.height {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(dotColor)
                    )
                    y += cell.height + ApexCanvasGrid.gap
                }
                x += cell.width + ApexCanvasGrid.gap
            }
        }
        .allowsHitTesting(false)
    }

    private func moveGhostRect(in size: CGSize) -> CGRect? {
        guard let movingID = canvasDrag.movingTileID,
              let tile = layout.tile(id: movingID) else { return nil }
        let frame = tile.frame(in: size)
        let moved = frame.offsetBy(dx: canvasDrag.dragTranslation.width,
                                   dy: canvasDrag.dragTranslation.height)
        // Snap by the tile centre so the panel drops where its bulk is dragged,
        // not where its top-left corner happens to be.
        let centerCell = ApexCanvasGrid.cell(at: CGPoint(x: moved.midX, y: moved.midY), in: size)
        let col = max(0, min(centerCell.col - tile.colSpan / 2,
                             ApexCanvasGrid.cols - tile.colSpan))
        let row = max(0, min(centerCell.row - tile.rowSpan / 2,
                             ApexCanvasGrid.rows - tile.rowSpan))
        return ApexCanvasGrid.frame(col: col, row: row, colSpan: tile.colSpan, rowSpan: tile.rowSpan, in: size)
    }
}

// MARK: - Canvas Tile View

struct ApexCanvasTileView: View {
    let tileID: UUID
    let canvasSize: CGSize
    let monitor: SystemMonitor

    @State private var layout = ApexWorkspaceLayoutState.shared
    @State private var canvasDrag = ApexCanvasDragState.shared
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        if let tile = layout.tile(id: tileID), tile.colSpan > 0, tile.rowSpan > 0 {
            let baseFrame = tile.frame(in: canvasSize)
            let isMoving = canvasDrag.movingTileID == tile.id
            let isResizing = canvasDrag.resizingTileID == tile.id
            let frame = baseFrame
                .offsetBy(dx: isMoving ? canvasDrag.dragTranslation.width : 0,
                          dy: isMoving ? canvasDrag.dragTranslation.height : 0)
                .resized(by: isResizing ? canvasDrag.resizeDelta : .zero,
                         anchor: canvasDrag.resizeAnchor)

            ApexPanelContainer(
                kind: tile.kind,
                isDraggable: !layout.isLocked,
                content: { ApexPanelContentView(kind: tile.kind, monitor: monitor) },
                onHeaderDragChanged: layout.isLocked ? nil : { value in headerDragChanged(value, tile: tile) },
                onHeaderDragEnded: layout.isLocked ? nil : { value in headerDragEnded(value, tile: tile) }
            )
            .frame(width: frame.width, height: frame.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.text.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) { resizeHandle(tile: tile, anchor: .bottomTrailing) }
            .overlay(alignment: .topLeading) { resizeHandle(tile: tile, anchor: .topLeading) }
            .position(x: frame.midX, y: frame.midY)
            .zIndex(isMoving ? 10_000 : Double(tile.z))
            .simultaneousGesture(
                TapGesture().onEnded {
                    layout.bringTileToFront(tileID)
                }
            )
        }
    }

    private func resizeHandle(tile: ApexCanvasTile, anchor: ApexCanvasDragState.ResizeAnchor) -> some View {
        Group {
            if !layout.isLocked {
                Canvas { context, size in
                    for i in 0..<3 {
                        let inset = CGFloat(i) * 6 + 4
                        var path = Path()
                        switch anchor {
                        case .bottomTrailing:
                            path.move(to: CGPoint(x: size.width - inset, y: size.height))
                            path.addLine(to: CGPoint(x: size.width, y: size.height - inset))
                        case .topLeading:
                            path.move(to: CGPoint(x: inset, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: inset))
                        }
                        context.stroke(path, with: .color(theme.text.opacity(0.4)), lineWidth: 1.5)
                    }
                }
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(ApexCanvasCoordinateSpace.name))
                        .onChanged { value in
                            if canvasDrag.resizingTileID != tile.id {
                                canvasDrag.resizingTileID = tile.id
                                canvasDrag.resizeAnchor = anchor
                                canvasDrag.resizeDelta = .zero
                                layout.bringTileToFront(tile.id)
                            }
                            canvasDrag.resizeDelta = value.translation
                        }
                        .onEnded { _ in
                            let delta = canvasDrag.resizeDelta
                            let anchor = canvasDrag.resizeAnchor
                            canvasDrag.resizingTileID = nil
                            canvasDrag.resizeDelta = .zero

                            let cell = ApexCanvasGrid.cellSize(in: canvasSize)
                            let base = tile.frame(in: canvasSize)
                            let deltaCols = Int((delta.width / (cell.width + ApexCanvasGrid.gap)).rounded())
                            let deltaRows = Int((delta.height / (cell.height + ApexCanvasGrid.gap)).rounded())

                            switch anchor {
                            case .bottomTrailing:
                                let newColSpan = max(tile.minColSpan, min(
                                    ApexCanvasGrid.cols - tile.col,
                                    tile.colSpan + deltaCols
                                ))
                                let newRowSpan = max(tile.minRowSpan, min(
                                    ApexCanvasGrid.rows - tile.row,
                                    tile.rowSpan + deltaRows
                                ))
                                layout.resizeTileSpan(tile.id, colSpan: newColSpan, rowSpan: newRowSpan)
                            case .topLeading:
                                let newColSpan = max(tile.minColSpan, tile.colSpan - deltaCols)
                                let newRowSpan = max(tile.minRowSpan, tile.rowSpan - deltaRows)
                                let newCol = max(0, min(tile.col + tile.colSpan - newColSpan,
                                                        ApexCanvasGrid.cols - newColSpan))
                                let newRow = max(0, min(tile.row + tile.rowSpan - newRowSpan,
                                                        ApexCanvasGrid.rows - newRowSpan))
                                layout.moveTile(tile.id, toCol: newCol, row: newRow)
                                layout.resizeTileSpan(tile.id, colSpan: newColSpan, rowSpan: newRowSpan)
                            }
                        }
                )
                .onHover { hovering in
                    if hovering { NSCursor.crosshair.push() } else { NSCursor.pop() }
                }
                .help("Drag to resize")
            }
        }
    }
}

private extension CGRect {
    func resized(by delta: CGSize, anchor: ApexCanvasDragState.ResizeAnchor) -> CGRect {
        switch anchor {
        case .bottomTrailing:
            return CGRect(x: minX, y: minY,
                          width: max(80, width + delta.width),
                          height: max(60, height + delta.height))
        case .topLeading:
            // Dragging the top-leading handle right/down shrinks from the top/left,
            // so the bottom-trailing corner stays anchored.
            let newWidth = max(80, width - delta.width)
            let newHeight = max(60, height - delta.height)
            return CGRect(x: maxX - newWidth, y: maxY - newHeight,
                          width: newWidth, height: newHeight)
        }
    }
}

// MARK: - Tile Move

extension ApexCanvasTileView {
    func headerDragChanged(_ value: DragGesture.Value, tile: ApexCanvasTile) {
        if canvasDrag.movingTileID != tile.id {
            canvasDrag.movingTileID = tile.id
            canvasDrag.dragTranslation = .zero
            layout.bringTileToFront(tile.id)
        }
        canvasDrag.dragTranslation = value.translation
        canvasDrag.pointer = value.location
    }

    func headerDragEnded(_ value: DragGesture.Value, tile: ApexCanvasTile) {
        let translation = canvasDrag.dragTranslation
        canvasDrag.movingTileID = nil
        canvasDrag.dragTranslation = .zero

        let localTiles = layout.tiles.filter { $0.id != tile.id }
        let pointer = value.location

        let baseFrame = tile.frame(in: canvasSize)
        let moved = baseFrame.offsetBy(dx: translation.width, dy: translation.height)
        // Snap by the tile centre, matching the ghost preview.
        let centerCell = ApexCanvasGrid.cell(at: CGPoint(x: moved.midX, y: moved.midY), in: canvasSize)
        let col = max(0, min(centerCell.col - tile.colSpan / 2,
                             ApexCanvasGrid.cols - tile.colSpan))
        let row = max(0, min(centerCell.row - tile.rowSpan / 2,
                             ApexCanvasGrid.rows - tile.rowSpan))
        let candidate = (col: col, row: row, colSpan: tile.colSpan, rowSpan: tile.rowSpan)
        let overlapped = localTiles.filter { ApexCanvasGrid.spansIntersect($0.cellSpan, candidate) }

        if overlapped.isEmpty {
            layout.moveTile(tile.id, toCol: col, row: row)
        } else if overlapped.count == 1, let other = overlapped.first {
            let otherFrame = other.frame(in: canvasSize)
            if otherFrame.contains(pointer) {
                layout.swapTiles(tile.id, other.id)
            }
        }
    }
}
