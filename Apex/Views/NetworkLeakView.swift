import SwiftUI

struct NetworkLeakView: View {
    let leakData: NetworkLeakData
    @State private var reportToShow: InvestigationReport?

    var body: some View {
        VStack(spacing: 6) {
            // Header with toggle
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 10))
                    Text("WAN Leak Monitor")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(Theme.text)

                Spacer()

                Toggle("Enabled", isOn: Binding(
                    get: { leakData.isEnabled },
                    set: { leakData.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 9))

                if leakData.unreadCount > 0 {
                    Text("\(leakData.unreadCount) new")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.red.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 6)

            Divider().background(Theme.surface1)

            if leakData.alerts.isEmpty {
                emptyState
            } else {
                alertList
            }
        }
        .padding(Theme.panelPadding)
        .sheet(item: $reportToShow) { report in
            InvestigationReportSheet(report: report)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 24))
                .foregroundStyle(Theme.green)
            Text("No WAN leaks detected")
                .font(.system(size: 11))
                .foregroundStyle(Theme.text)
            Text("Background processes contacting the public internet will appear here.")
                .font(.system(size: 9))
                .foregroundStyle(Theme.overlay1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    private var alertList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(leakData.alerts.prefix(50)) { alert in
                    LeakAlertCard(
                        alert: alert,
                        leakData: leakData,
                        onShowInvestigation: { reportToShow = alert.investigation },
                        onInvestigate: {
                            Task {
                                await leakData.investigate(alert)
                                reportToShow = alert.investigation
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct LeakAlertCard: View {
    let alert: WANConnectionAlert
    let leakData: NetworkLeakData
    let onShowInvestigation: () -> Void
    let onInvestigate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                riskDot

                Text(alert.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Spacer()

                Text(alert.displayEndpoint)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
                    .lineLimit(1)
            }

            if alert.resolvedHostname != nil {
                Text(alert.remoteEndpoint)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Theme.overlay1)
                    .lineLimit(1)
            }

            Text(alert.reason)
                .font(.system(size: 9))
                .foregroundStyle(Theme.subtext1)
                .lineLimit(2)

            Text(alert.advice)
                .font(.system(size: 8))
                .foregroundStyle(Theme.overlay0)
                .lineLimit(3)

            HStack(spacing: 6) {
                Button("Allow always") {
                    leakData.approve(alert)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Theme.green)

                Button("Silence endpoint") {
                    leakData.silenceEndpoint(alert)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Theme.yellow)

                Button("Dismiss") {
                    leakData.dismiss(alert)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 8))
                .foregroundStyle(Theme.overlay1)

                Spacer()

                if alert.investigation != nil {
                    Button("View findings") {
                        onShowInvestigation()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                } else {
                    Button("Investigate") {
                        onInvestigate()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                }

                Text(timeAgo)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
            }
        }
        .padding(6)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var riskDot: some View {
        Circle()
            .fill(riskColor)
            .frame(width: 8, height: 8)
            .help("Risk: \(alert.risk.rawValue)")
    }

    private var riskColor: Color {
        switch alert.risk {
        case .low:    return Theme.green
        case .medium: return Theme.yellow
        case .high:   return Theme.red
        }
    }

    private var cardBackground: Color {
        switch alert.risk {
        case .low:    return Theme.green.opacity(0.06)
        case .medium: return Theme.yellow.opacity(0.06)
        case .high:   return Theme.red.opacity(0.08)
        }
    }

    private var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(alert.timestamp))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }
}

// MARK: - Investigation Report Sheet

private struct InvestigationReportSheet: View {
    let report: InvestigationReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Investigation findings")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.borderless)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(report.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.text)

                    if let path = report.executablePath {
                        detailRow(title: "Executable", value: path)
                    }
                    if let name = report.bundleName {
                        detailRow(title: "Bundle name", value: name)
                    }
                    if let id = report.bundleIdentifier {
                        detailRow(title: "Bundle ID", value: id)
                    }
                    if let cl = report.commandLine {
                        detailRow(title: "Command line", value: cl)
                    }

                    ForEach(report.configFindings) { finding in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(finding.source)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.blue)
                            Text(finding.detail)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.subtext1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 220, idealHeight: 320)
        .background(Theme.base)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.overlay0)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.subtext1)
                .textSelection(.enabled)
        }
    }
}
