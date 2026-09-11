import SwiftUI

struct ProcessView: View {
    let processes: ProcessData
    @State private var filterText = ""

    var body: some View {
        VStack(spacing: 6) {
                // Search + sort controls
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.overlay1)
                    TextField("Filter...", text: $filterText)
                        .font(.system(size: 10, design: .monospaced))
                        .textFieldStyle(.plain)
                        .foregroundStyle(Theme.text)
                        .onChange(of: filterText) { processes.filter = filterText }

                    Spacer()

                    Text("\(processes.filtered.count) procs")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.overlay0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Theme.surface1.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 5))

                // Header row
                ProcessRowHeader(processes: processes)

                Divider().background(Theme.surface1)

                // Process list
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 1) {
                        ForEach(processes.filtered.prefix(200)) { proc in
                            ProcessRow(proc: proc)
                                .contextMenu {
                                    Button("Kill (SIGTERM)", role: .destructive) {
                                        Task { await HelperManager.shared.kill(pid: proc.id, signal: SIGTERM) }
                                    }
                                    Button("Force Kill (SIGKILL)", role: .destructive) {
                                        Task { await HelperManager.shared.kill(pid: proc.id, signal: SIGKILL) }
                                    }
                                }
                        }
                    }
                }
            }
        .padding(Theme.panelPadding)
    }
}

// MARK: - Header row with sort buttons
private struct ProcessRowHeader: View {
    let processes: ProcessData

    var body: some View {
        HStack(spacing: 0) {
            SortButton(label: "PID",    key: .pid,     width: 50,  processes: processes)
            SortButton(label: "Name",   key: .name,    width: nil, processes: processes)
            SortButton(label: "User",   key: .user,    width: 70,  processes: processes)
            SortButton(label: "CPU%",   key: .cpu,     width: 55,  processes: processes)
            SortButton(label: "Memory", key: .memory,  width: 70,  processes: processes)
            SortButton(label: "Thd",   key: .threads, width: 35,  processes: processes)
            Text("Status")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.overlay0)
                .frame(width: 45, alignment: .leading)
        }
    }
}

private struct SortButton: View {
    let label: String
    let key: ProcessData.SortKey
    let width: CGFloat?
    let processes: ProcessData

    private var isActive: Bool { processes.sortKey == key }

    var body: some View {
        Button {
            if isActive {
                processes.sortAscending.toggle()
            } else {
                processes.sortKey = key
                processes.sortAscending = false
            }
        } label: {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                if isActive {
                    Image(systemName: processes.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7))
                }
            }
            .foregroundStyle(isActive ? Theme.procColor : Theme.overlay0)
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: .leading)
        // When width is nil, fill remaining space like data rows do
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

// MARK: - Individual process row
private struct ProcessRow: View {
    let proc: ProcessSnapshot

    var body: some View {
        HStack(spacing: 0) {
            Text("\(proc.id)")
                .frame(width: 50, alignment: .leading)
            Text(proc.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(proc.user)
                .lineLimit(1)
                .frame(width: 70, alignment: .leading)
            Text(String(format: "%.1f", proc.cpuPercent))
                .foregroundStyle(Theme.loadColor(proc.cpuPercent / 100))
                .frame(width: 55, alignment: .leading)
            Text(proc.memoryBytes.formattedBytes)
                .frame(width: 70, alignment: .leading)
            Text("\(proc.threads)")
                .frame(width: 35, alignment: .leading)
            Text(proc.status)
                .foregroundStyle(statusColor)
                .frame(width: 45, alignment: .leading)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Theme.subtext1)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch proc.status {
        case "Run":    return Theme.green
        case "Zombie": return Theme.red
        case "Stop":   return Theme.yellow
        default:       return Theme.overlay1
        }
    }
}
