import SwiftUI

// MARK: - Apex Panel Container
/// Wraps a dashboard panel with a header: drag grip, icon, title, and close.
struct ApexPanelContainer<Content: View>: View {
    let kind: ApexPanelKind
    var isDraggable: Bool = true
    @ViewBuilder let content: () -> Content

    /// Canvas-mode drag callbacks forwarded from the hosting tile view.
    var onHeaderDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onHeaderDragEnded: ((DragGesture.Value) -> Void)? = nil

    @State private var layout = ApexWorkspaceLayoutState.shared
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header
                .fixedSize(horizontal: false, vertical: true)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        .background(theme.surface0.opacity(0.6))
    }

    private var header: some View {
        headerRow
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.surface1.opacity(0.5))
            .applyDragIfNeeded(
                onChanged: isDraggable ? onHeaderDragChanged : nil,
                onEnded: isDraggable ? onHeaderDragEnded : nil
            )
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: isDraggable ? "line.3.horizontal" : "lock")
                .font(.caption)
                .foregroundStyle(theme.subtext0)
                .frame(width: 22, height: 20)
                .help(isDraggable ? "Drag to move" : "Workspace is locked")

            Image(systemName: kind.icon)
                .font(.caption)
                .foregroundStyle(theme.panelAccent(for: kind))

            Text(kind.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.panelAccent(for: kind))
                .lineLimit(1)

            Spacer()

            Menu {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        layout.close(kind)
                    }
                } label: {
                    Label("Close Panel", systemImage: "xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(theme.subtext0)
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    layout.close(kind)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(theme.subtext0)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Close panel")
        }
    }
}

private extension View {
    @ViewBuilder
    func applyDragIfNeeded(
        onChanged: ((DragGesture.Value) -> Void)?,
        onEnded: ((DragGesture.Value) -> Void)?
    ) -> some View {
        if let onChanged {
            self
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .named(ApexCanvasCoordinateSpace.name))
                        .onChanged(onChanged)
                        .onEnded { value in onEnded?(value) }
                )
        } else {
            self
        }
    }
}
