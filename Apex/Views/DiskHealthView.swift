import SwiftUI

/// Storage Health panel for ApexFlow.
///
/// Lists every mounted disk, shows capacity/health bars, SMART status,
/// temperature, power-on hours, and warns when a drive should be replaced.
struct DiskHealthView: View {
    let disk: DiskData

    @State private var isScanning = false
    @State private var metricStore = DiskHealthMetricsStore.shared

    var body: some View {
        VStack(spacing: 0) {
                header
                Divider().background(Theme.surface1)

                if disk.disks.isEmpty {
                    Text("No disks")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.overlay0)
                        .padding()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(disk.disks) { volume in
                                DiskHealthRow(volume: volume)
                            }
                        }
                        .padding(8)
                    }
                }
            }
        .padding(Theme.panelPadding)
    }

    private var header: some View {
        HStack {
            Text("S.M.A.R.T. & Health")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.text)
            Spacer()
            if isScanning {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning…")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.subtext0)
            }
            metricsMenu
            Button {
                Task { await refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            .disabled(isScanning)
        }
        .padding(8)
    }

    private var metricsMenu: some View {
        let categories = Dictionary(grouping: DiskHealthMetric.allCases, by: \.category)
        return Menu {
            ForEach(categories.keys.sorted(), id: \.self) { category in
                Section(category) {
                    let metrics = categories[category]?
                        .sorted(by: { $0.displayName < $1.displayName }) ?? []
                    ForEach(metrics) { metric in
                        Toggle(metric.displayName, isOn: metricBinding(for: metric))
                    }
                }
            }
            Divider()
            Button("Reset to defaults") {
                metricStore.resetToDefaults()
            }
        } label: {
            Label("Metrics", systemImage: "line.3.horizontal.decrease.circle")
                .font(.system(size: 10))
                .foregroundStyle(Theme.text)
        }
        .menuStyle(.borderlessButton)
    }

    private func metricBinding(for metric: DiskHealthMetric) -> Binding<Bool> {
        Binding(
            get: { metricStore.isSelected(metric) },
            set: { _ in metricStore.toggle(metric) }
        )
    }

    private func refresh() async {
        isScanning = true
        defer { isScanning = false }
        // Run a full, user-requested scan (verifyVolume + smartctl).  This is
        // intentionally not on the automatic timer because it can be I/O heavy.
        let service = DiskHealthService.shared
        for volume in disk.disks {
            let url = URL(fileURLWithPath: volume.mountpoint)
            if let health = await service.healthSnapshot(for: url, depth: .full) {
                disk.update(health: health, for: volume.id)
            }
            // Yield between drives so a slow external/sleeping disk doesn't
            // monopolize the I/O subsystem.
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}

// MARK: - Row

private struct DiskHealthRow: View {
    let volume: DiskInfo
    @State private var metricStore = DiskHealthMetricsStore.shared

    private var health: DiskHealth? {
        volume.health
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text(volume.name)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.text)
                    if volume.healthWarnReplace {
                        Label("Replace recommended", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.red)
                    }
                }
                Spacer()
                if let score = health?.score {
                    HealthScoreBadge(score: score)
                }
            }

            if volume.totalBytes > 0 {
                CapacityBar(
                    usedBytes: Int64(volume.usedBytes),
                    totalBytes: Int64(volume.totalBytes)
                )
            }

            if let health {
                let columns = [GridItem(.adaptive(minimum: 110), spacing: 6)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
                    ForEach(DiskHealthMetric.allCases.filter { metricStore.isSelected($0) }) { metric in
                        metricPill(for: metric, health: health)
                    }
                }

                if let message = health.message {
                    Text(message)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.subtext0)
                        .lineLimit(2)
                }
            } else {
                Text("No health snapshot yet. Click Refresh.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
            }
        }
        .padding(8)
        .background(Theme.surface0.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelCornerRadius)
                .stroke(Theme.surface1, lineWidth: Theme.panelBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelCornerRadius))
    }

    @ViewBuilder
    private func metricPill(for metric: DiskHealthMetric, health: DiskHealth) -> some View {
        if let (label, value, color) = metricValue(metric: metric, health: health) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
                Text(value)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private func metricValue(
        metric: DiskHealthMetric,
        health: DiskHealth
    ) -> (label: String, value: String, color: Color)? {
        switch metric {
        case .smartStatus:
            guard let v = health.smartStatus else { return nil }
            let color: Color = health.status == .failing ? Theme.red : (health.status == .caution ? Theme.yellow : Theme.green)
            return (metric.displayName, v, color)
        case .healthScore:
            let score = health.score
            let color: Color = score >= 80 ? Theme.green : (score >= 50 ? Theme.yellow : Theme.red)
            return (metric.displayName, "\(score)", color)
        case .freeSpace:
            guard let v = health.freeSpacePercent else { return nil }
            let color: Color = v < 10 ? Theme.red : (v < 20 ? Theme.yellow : Theme.green)
            return (metric.displayName, "\(v)%", color)
        case .filesystemVerify:
            guard let ok = health.filesystemVerifyOK else { return nil }
            return (metric.displayName, ok ? "Verified" : "Failed", ok ? Theme.green : Theme.red)
        case .temperature:
            guard let v = health.temperatureC else { return nil }
            let color: Color = v > 70 ? Theme.red : (v > 55 ? Theme.yellow : Theme.green)
            return (metric.displayName, "\(v)°C", color)
        case .powerOnHours:
            guard let v = health.powerOnHours else { return nil }
            return (metric.displayName, formatHours(v), Theme.overlay0)
        case .powerCycles, .startStops, .loadCycles, .udmaCRCErrors,
             .reallocatedSectors, .pendingSectors, .offlineUncorrectable,
             .gSenseErrors, .multiZoneErrors:
            guard let v = countFor(metric, health) else { return nil }
            let isErrorMetric: Bool = {
                switch metric {
                case .udmaCRCErrors, .offlineUncorrectable, .reallocatedSectors,
                     .pendingSectors, .gSenseErrors, .multiZoneErrors:
                    return true
                default:
                    return false
                }
            }()
            let color: Color = (isErrorMetric && v > 0) ? Theme.red : Theme.overlay0
            return (metric.displayName, "\(v)", color)
        case .wearLevel:
            guard let v = health.wearLevelPercent else { return nil }
            let color: Color = v > 90 ? Theme.red : (v > 80 ? Theme.yellow : Theme.green)
            return (metric.displayName, "\(v)%", color)
        case .percentageUsed:
            guard let v = health.percentageUsed else { return nil }
            let color: Color = v > 90 ? Theme.red : (v > 80 ? Theme.yellow : Theme.green)
            return (metric.displayName, "\(v)%", color)
        case .fileVault:
            guard let v = health.fileVaultEnabled else { return nil }
            return (metric.displayName, v ? "On" : "Off", v ? Theme.green : Theme.overlay0)
        case .encryption:
            guard let v = health.encryptionEnabled else { return nil }
            return (metric.displayName, v ? "On" : "Off", v ? Theme.green : Theme.overlay0)
        case .timeMachineBackup:
            guard let d = health.timeMachineLastBackup else { return nil }
            let formatter = RelativeDateTimeFormatter()
            return (metric.displayName, formatter.localizedString(for: d, relativeTo: Date()), Theme.overlay0)
        case .busProtocol:
            guard let v = health.busProtocol else { return nil }
            return (metric.displayName, v, Theme.overlay0)
        case .isSSD:
            guard let v = health.isSSD else { return nil }
            return (metric.displayName, v ? "SSD" : "HDD", Theme.overlay0)
        }
    }

    private func countFor(_ metric: DiskHealthMetric, _ health: DiskHealth) -> Int? {
        switch metric {
        case .powerCycles:        return health.powerCycleCount
        case .startStops:         return health.startStopCount
        case .loadCycles:         return health.loadCycleCount
        case .udmaCRCErrors:      return health.udmaCRCErrorCount
        case .reallocatedSectors: return health.reallocatedSectorCount
        case .pendingSectors:     return health.pendingSectorCount
        case .offlineUncorrectable: return health.offlineUncorrectable
        case .gSenseErrors:       return health.gSenseErrorRate
        case .multiZoneErrors:    return health.multiZoneErrorCount
        default:                  return nil
        }
    }

    private var iconName: String {
        switch health?.status {
        case .healthy: return "externaldrive.fill.badge.checkmark"
        case .caution: return "externaldrive.fill.badge.exclamationmark"
        case .failing: return "externaldrive.fill.badge.xmark"
        case .unsupported, .unknown, .none: return "externaldrive.fill"
        }
    }

    private var statusColor: Color {
        switch health?.status {
        case .healthy: return Theme.green
        case .caution: return Theme.yellow
        case .failing: return Theme.red
        case .unsupported, .unknown, .none: return Theme.overlay0
        }
    }

    private func formatHours(_ hours: Int) -> String {
        let days = hours / 24
        if days >= 365 {
            return String(format: "%.1f years", Double(days) / 365.0)
        } else if days >= 30 {
            return String(format: "%.1f months", Double(days) / 30.0)
        } else {
            return "\(days) days"
        }
    }
}

// MARK: - Subviews

private struct HealthScoreBadge: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(scoreColor.readableOverlayColor())
            .frame(width: 40, height: 40)
            .background(scoreColor, in: Circle())
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: return Theme.green
        case 50..<80: return Theme.yellow
        default: return Theme.red
        }
    }
}

private struct CapacityBar: View {
    let usedBytes: Int64
    let totalBytes: Int64

    private var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(usedBytes) / Double(totalBytes)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.surface1)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(fraction > 0.9 ? Theme.red : Theme.teal)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            HStack {
                Text("Used: \(ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file))")
                Spacer()
                Text("Total: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(Theme.overlay0)
        }
    }
}
