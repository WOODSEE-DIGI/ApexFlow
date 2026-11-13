import SwiftUI

// MARK: - Emergency Warning View
/// Full-screen warning UI with a prominent kill switch. Used when the app
/// detects runaway CPU/memory or when the user triggers the manual panic
/// button.
struct EmergencyWarningView: View {
    let reason: EmergencyReason
    let detail: String
    let targetPID: Int32
    let onDismiss: () -> Void
    let onKill: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Pulsing warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(.yellow)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .opacity(pulse ? 1.0 : 0.7)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)

                VStack(spacing: 12) {
                    Text("SYSTEM PROTECTION WARNING")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text(reason.rawValue)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Text(detail)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)

                Text("If ApexFlow is unresponsive or consuming excessive system resources, terminate it now. This will close the app immediately.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)

                Spacer()

                HStack(spacing: 24) {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Dismiss Warning")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .keyboardShortcut(.escape, modifiers: [])

                    Button {
                        onKill()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "power")
                            Text("KILL APEXFLOW (PID \(targetPID))")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.return, modifiers: [])
                }

                Spacer().frame(height: 40)
            }
            .padding(40)
        }
        .onAppear { pulse = true }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
