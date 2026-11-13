import SwiftUI

// MARK: - National Security Warning View
/// Over-the-top, full-screen warning for system-wide resource threats.
/// Designed to fit on small displays (e.g. a 1600x900 teleprompter) while
/// remaining dramatic.
struct NationalSecurityWarningView: View {
    let threats: [ThreatAssessment]
    let onDismiss: () -> Void
    let onKill: (Int32) -> Void

    @State private var pulse = false
    @State private var flash = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Flashing red alert background
                Color.red.opacity(flash ? 0.25 : 0.05)
                    .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: flash)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Fixed header
                    VStack(spacing: 6) {
                        Text("TOP SECRET // NOFORN")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .overlay(
                                Rectangle()
                                    .stroke(.red, lineWidth: 1)
                            )

                        Text("SYSTEM HOG DETECTED")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.red)
                            .tracking(3)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    HStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(.yellow)
                            .scaleEffect(pulse ? 1.15 : 1.0)
                            .shadow(color: .red, radius: pulse ? 20 : 6)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("HOSTILE PROCESS DETECTED")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)

                            Text("ApexFlow has identified system resource activity that requires your immediate attention.")
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
                                        .foregroundStyle(.red)
                                        .frame(width: 120, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(threat.name) (PID \(threat.pid))")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if threat.reason == .systemPressure {
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

                                    if threat.pid > 0 {
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
                                        .stroke(.red, lineWidth: 2)
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
