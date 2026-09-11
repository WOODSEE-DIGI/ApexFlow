import SwiftUI
import Charts

struct CPUView: View {
    let cpu: CPUData

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: core grid
            VStack(alignment: .leading, spacing: 6) {
                if !cpu.coreUsages.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 4) {
                        ForEach(Array(cpu.coreUsages.enumerated()), id: \.offset) { idx, usage in
                            CoreCell(index: idx, usage: usage)
                        }
                    }
                }
                // Load averages + stats row
                HStack(spacing: 12) {
                    StatLabel(key: "1m", value: String(format: "%.2f", cpu.loadAvg.0))
                    StatLabel(key: "5m", value: String(format: "%.2f", cpu.loadAvg.1))
                    StatLabel(key: "15m", value: String(format: "%.2f", cpu.loadAvg.2))
                    Spacer()
                    if let temp = cpu.temperature {
                        StatLabel(key: "temp", value: String(format: "%.0f°C", temp),
                                  valueColor: Theme.loadColor(temp / 100))
                    }
                    StatLabel(key: "up", value: cpu.formattedUptime)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: 280)

            // Right: history chart
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Spacer()
                    Text(String(format: "%.0f%%", cpu.totalUsage * 100))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.loadColor(cpu.totalUsage))
                }
                SparklineView(data: cpu.history,
                              color: Theme.loadColor(cpu.totalUsage),
                              domain: 0...1,
                              height: 50)

                Text(cpu.cpuName.isEmpty ? "CPU" : cpu.cpuName)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Theme.panelPadding)
    }
}

private struct CoreCell: View {
    let index: Int
    let usage: Double

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.surface1)
                    .frame(height: 20)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.loadColor(usage).opacity(0.85))
                    .frame(height: 20)
                    .scaleEffect(x: CGFloat(usage), anchor: .leading)
            }
            Text("\(index)")
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(Theme.overlay0)
        }
    }
}
