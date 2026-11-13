import SwiftUI

// MARK: - National Security Warning View
/// Over-the-top, full-screen warning for system-wide resource threats.
/// Designed to fit on small displays (e.g. a 1600x900 teleprompter) while
/// remaining dramatic.
struct NationalSecurityWarningView: View {
    let threats: [ThreatAssessment]
    let networkLeakData: NetworkLeakData?
    let onDismiss: () -> Void
    let onKill: (Int32) -> Void

    @State private var pulse = false
    @State private var flash = false

    /// The visual theme for this warning. WAN leaks use an amber/blue alert
    /// palette; system resource threats keep the original red.
    private var theme: WarningTheme {
        let wanOnly = threats.allSatisfy(\.isWANLeak)
        return wanOnly ? .wanLeak : .systemThreat
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Flashing alert background
                theme.background.opacity(flash ? 0.25 : 0.05)
                    .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: flash)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Fixed header
                    VStack(spacing: 6) {
                        Text("TOP SECRET // NOFORN")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(theme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .overlay(
                                Rectangle()
                                    .stroke(theme.primary, lineWidth: 1)
                            )

                        Text(theme.title)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(theme.primary)
                            .tracking(3)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    HStack(spacing: 16) {
                        Image(systemName: theme.icon)
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(theme.accent)
                            .scaleEffect(pulse ? 1.15 : 1.0)
                            .shadow(color: theme.primary, radius: pulse ? 20 : 6)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(theme.headline)
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)

                            Text(theme.subheadline)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // Scrollable threat list, constrained so the button stays visible.
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(threats) { threat in
                                HStack(spacing: 12) {
                                    Text(threat.reason.rawValue)
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundStyle(theme.primary)
                                        .frame(width: 120, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(threat.name) (PID \(threat.pid))")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if threat.isWANLeak {
                                            WANLeakDetailsView(
                                                threat: threat,
                                                networkLeakData: networkLeakData,
                                                onKill: onKill,
                                                onDismiss: onDismiss
                                            )
                                        } else if threat.reason == .systemPressure {
                                            Text("System memory usage: \(threat.formattedMemory) / \(threat.memoryPercent, specifier: "%.1f")%")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.8))
                                        } else {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Memory: \(threat.formattedMemory) (\(threat.memoryPercent, specifier: "%.1f")%)")
                                                Text("CPU: \(threat.cpuPercent, specifier: "%.1f")%")
                                            }
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.8))
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    if threat.pid > 0 && !threat.isWANLeak {
                                        if isCriticalSystemProcess(name: threat.name) {
                                            Text("PROTECTED")
                                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                                .foregroundStyle(.orange)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .overlay(
                                                    Rectangle()
                                                        .stroke(.orange, lineWidth: 1)
                                                )
                                        } else {
                                            Button {
                                                onKill(threat.pid)
                                            } label: {
                                                Text("NEUTRALIZE")
                                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.red)
                                            .contentShape(Rectangle())
                                        }
                                    }
                                }
                                .padding(10)
                                .background(.black.opacity(0.5))
                                .overlay(
                                    Rectangle()
                                        .stroke(theme.primary, lineWidth: 2)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height - 220)
                    }

                    // Fixed footer with STAND DOWN
                    Button {
                        onDismiss()
                    } label: {
                        Text("STAND DOWN")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .keyboardShortcut(.escape, modifiers: [])
                    .contentShape(Rectangle())
                    .padding(.bottom, 16)
                    .padding(.top, 10)
                }
            }
            .onAppear {
                pulse = true
                flash = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func isCriticalSystemProcess(name: String) -> Bool {
        let critical = [
            "WindowServer", "kernel_task", "launchd", "loginwindow",
            "securityd", "trustd", "akd", "cloudd", "nsattributedstringagent",
            "dasd", "coreduetd", "powerd", "thermalmonitord", "watchdogd"
        ]
        return critical.contains(name)
    }
}

// MARK: - WAN Leak Details View

private struct WANLeakDetailsView: View {
    let threat: ThreatAssessment
    let networkLeakData: NetworkLeakData?
    let onKill: (Int32) -> Void
    let onDismiss: () -> Void

    /// The original WAN alert, if it still exists in the data store.
    private var alert: WANConnectionAlert? {
        guard let alertID = threat.alertID else { return nil }
        return networkLeakData?.alerts.first { $0.id == alertID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Endpoint / risk / advice
            VStack(alignment: .leading, spacing: 2) {
                if let endpoint = threat.remoteEndpoint {
                    Text("Endpoint: \(endpoint)")
                }
                if let risk = threat.wanRisk {
                    Text("Risk: \(risk.rawValue)")
                }
                if let advice = threat.wanAdvice {
                    Text(advice)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.white.opacity(0.8))

            // Investigation findings
            if let report = alert?.investigation {
                VStack(alignment: .leading, spacing: 2) {
                    if let bundleName = report.bundleName {
                        Text("App: \(bundleName)")
                    } else if let bundleID = report.bundleIdentifier {
                        Text("Bundle: \(bundleID)")
                    }
                    if let path = report.executablePath {
                        Text("Path: \(path)")
                    }
                    if let cmd = report.commandLine {
                        Text("Command: \(cmd)")
                    }
                    if !report.configFindings.isEmpty {
                        ForEach(report.configFindings) { finding in
                            Text("\(finding.source): \(finding.detail)")
                        }
                    }
                    Text(report.summary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(8)
                .background(.black.opacity(0.35))
                .cornerRadius(4)
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text("Investigating process...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Action buttons
            HStack(spacing: 10) {
                if let alert = alert {
                    Button {
                        networkLeakData?.approve(alert)
                        onDismiss()
                    } label: {
                        Text("ALWAYS ALLOW")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .help("Trust this app and stop warning about it")

                    Button {
                        networkLeakData?.silenceEndpoint(alert)
                        onDismiss()
                    } label: {
                        Text("SILENCE ENDPOINT")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .help("Stop warning about this endpoint")
                }

                if threat.pid > 0 && !isCriticalSystemProcess(name: threat.name) {
                    Button {
                        onKill(threat.pid)
                        onDismiss()
                    } label: {
                        Text("KILL")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .help("Terminate the process")
                }

                Button {
                    onDismiss()
                } label: {
                    Text("DISMISS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Spacer()

                if let gateway = defaultGatewayIP() {
                    Button {
                        openGateway(gateway)
                    } label: {
                        Label("Gateway", systemImage: "network")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .buttonStyle(.borderless)
                    .help("Open router/firewall at \(gateway)")
                }
            }
        }
    }

    private func isCriticalSystemProcess(name: String) -> Bool {
        let critical = [
            "WindowServer", "kernel_task", "launchd", "loginwindow",
            "securityd", "trustd", "akd", "cloudd", "nsattributedstringagent",
            "dasd", "coreduetd", "powerd", "thermalmonitord", "watchdogd"
        ]
        return critical.contains(name)
    }

    private func defaultGatewayIP() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.arguments = ["-rn", "-f", "inet"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else { return nil }
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("default"),
               let gateway = trimmed.components(separatedBy: .whitespaces).dropFirst().first,
               !gateway.isEmpty {
                return gateway
            }
        }
        return nil
    }

    private func openGateway(_ gateway: String) {
        guard let url = URL(string: "http://\(gateway)") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Warning Theme

private enum WarningTheme {
    case systemThreat
    case wanLeak

    /// Primary theme color used for headers, borders, and flashing background.
    var primary: Color {
        switch self {
        case .systemThreat: return .red
        case .wanLeak:      return .orange
        }
    }

    /// Accent color used for the large icon.
    var accent: Color {
        switch self {
        case .systemThreat: return .yellow
        case .wanLeak:      return .cyan
        }
    }

    var background: Color {
        switch self {
        case .systemThreat: return .red
        case .wanLeak:      return .orange
        }
    }

    var icon: String {
        switch self {
        case .systemThreat: return "exclamationmark.triangle.fill"
        case .wanLeak:      return "network.badge.shield.half.filled"
        }
    }

    var title: String {
        switch self {
        case .systemThreat: return "SYSTEM HOG DETECTED"
        case .wanLeak:      return "WAN LEAK DETECTED"
        }
    }

    var headline: String {
        switch self {
        case .systemThreat: return "HOSTILE PROCESS DETECTED"
        case .wanLeak:      return "OUTBOUND CONNECTION DETECTED"
        }
    }

    var subheadline: String {
        switch self {
        case .systemThreat:
            return "ApexFlow has identified system resource activity that requires your immediate attention."
        case .wanLeak:
            return "ApexFlow has detected an unexpected outbound connection to the public internet."
        }
    }
}
