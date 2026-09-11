import SwiftUI
import Charts

struct MemoryView: View {
    let memory: MemoryData
    let disk: DiskData

    var body: some View {
        VStack(spacing: 8) {
            // RAM section
            VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("RAM")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.subtext0)
                        Spacer()
                        Text(memory.usedBytes.formattedBytes + " / " + memory.totalBytes.formattedBytes)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.text)
                    }

                    // Stacked usage bar: used | cached | free
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.memColor)
                                .frame(width: geo.size.width * CGFloat(memory.usedFraction))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.teal.opacity(0.6))
                                .frame(width: geo.size.width * CGFloat(memory.cachedFraction))
                            Spacer(minLength: 0)
                        }
                        .background(Theme.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    .frame(height: 7)

                    HStack(spacing: 10) {
                        LegendDot(color: Theme.memColor, label: "Used", value: memory.usedBytes.formattedBytes)
                        LegendDot(color: Theme.teal,     label: "Cached", value: memory.cachedBytes.formattedBytes)
                        LegendDot(color: Theme.surface2, label: "Free", value: memory.availableBytes.formattedBytes)
                        if memory.swapTotal > 0 {
                            Spacer()
                            LegendDot(color: Theme.yellow, label: "Swap",
                                      value: memory.swapUsed.formattedBytes + "/" + memory.swapTotal.formattedBytes)
                        }
                    }
                }

                Divider().background(Theme.surface1)

                // Disk list — scrollable so it doesn’t overflow the panel
                if disk.disks.isEmpty {
                    Text("No disks")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.overlay0)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 5) {
                            ForEach(disk.disks) { d in
                                DiskRow(disk: d)
                            }
                        }
                    }
                }
            }
        .padding(Theme.panelPadding)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.overlay1)
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.text)
        }
    }
}

private struct DiskRow: View {
    let disk: DiskInfo

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(disk.name)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)

                    Spacer()

                    if disk.healthWarnReplace {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.red)
                            .font(.system(size: 10))
                            .help("Drive health indicates replacement is recommended")
                    }

                    if let temp = disk.health?.temperatureC {
                        Text("\(temp)°C")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(temp > 70 ? Theme.red : Theme.overlay0)
                    }

                    Text(String(format: "%.0f%%", disk.usedFraction * 100))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.loadColor(disk.usedFraction))
                }
                MeterView(value: disk.usedFraction,
                          color: Theme.loadColor(disk.usedFraction),
                          height: 5)
                HStack(spacing: 6) {
                    StatLabel(key: "R", value: disk.readRate.formattedRate,  valueColor: Theme.diskRead)
                    StatLabel(key: "W", value: disk.writeRate.formattedRate, valueColor: Theme.diskWrite)
                    Spacer()
                    if let health = disk.health {
                        HealthStatusPill(health: health)
                    }
                    Text(disk.freeBytes.formattedBytes + " free")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.overlay0)
                }
            }
            .frame(maxWidth: .infinity)

            // Mini dual sparkline
            VStack(spacing: 1) {
                SparklineView(data: disk.readHistory,  color: Theme.diskRead,  height: 14)
                SparklineView(data: disk.writeHistory, color: Theme.diskWrite, height: 14)
            }
            .frame(width: 60)
        }
    }
}

private struct HealthStatusPill: View {
    let health: DiskHealth

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 8))
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var label: String {
        switch health.status {
        case .healthy: return "OK"
        case .caution: return "Caution"
        case .failing: return "Failing"
        case .unsupported: return "No SMART"
        case .unknown: return "Unknown"
        }
    }

    private var color: Color {
        switch health.status {
        case .healthy: return Theme.green
        case .caution: return Theme.yellow
        case .failing: return Theme.red
        case .unsupported, .unknown: return Theme.overlay0
        }
    }

    private var iconName: String {
        switch health.status {
        case .healthy: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .failing: return "xmark.shield.fill"
        case .unsupported, .unknown: return "questionmark.circle"
        }
    }
}
