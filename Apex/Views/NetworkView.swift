import SwiftUI
import Charts

struct NetworkView: View {
    let network: NetworkData

    private var selected: InterfaceInfo? {
        network.interfaces.first(where: { $0.id == network.selectedInterface })
            ?? network.interfaces.first
    }

    var body: some View {
        VStack(spacing: 6) {
                // Interface selector — compact dropdown avoids overflow with many interfaces
                HStack(spacing: 6) {
                    if network.interfaces.count > 1 {
                        Menu {
                            ForEach(network.interfaces) { iface in
                                Button {
                                    network.selectedInterface = iface.id
                                } label: {
                                    Label(
                                        iface.id + (iface.ipv4.isEmpty ? "" : "  " + iface.ipv4),
                                        systemImage: iface.isConnected ? "wifi" : "wifi.slash"
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(selected?.isConnected == true ? Theme.green : Theme.overlay0)
                                    .frame(width: 6, height: 6)
                                Text(network.selectedInterface.isEmpty ? "Select" : network.selectedInterface)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.text)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 7))
                                    .foregroundStyle(Theme.overlay1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.surface1.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .menuStyle(.borderlessButton)
                    }
                    Spacer()
                }

                if let iface = selected {
                    // Rate display
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.netDown)
                                Text(iface.downloadRate.formattedRate)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.netDown)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.netUp)
                                Text(iface.uploadRate.formattedRate)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.netUp)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if !iface.ipv4.isEmpty {
                                Text(iface.ipv4)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Theme.overlay1)
                            }
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(iface.isConnected ? Theme.green : Theme.red)
                                    .frame(width: 6, height: 6)
                                Text(iface.isConnected ? "Connected" : "Down")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Theme.overlay1)
                            }
                        }
                    }

                    // Dual area chart
                    let peak = iface.peakRate
                    Chart {
                        ForEach(iface.downloadHistory) { p in
                            AreaMark(x: .value("t", p.time), y: .value("dl", p.value))
                                .foregroundStyle(.linearGradient(
                                    colors: [Theme.netDown.opacity(0.7), Theme.netDown.opacity(0.05)],
                                    startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("t", p.time), y: .value("dl", p.value))
                                .foregroundStyle(Theme.netDown)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                        ForEach(iface.uploadHistory) { p in
                            AreaMark(x: .value("t", p.time), y: .value("ul", -p.value))
                                .foregroundStyle(.linearGradient(
                                    colors: [Theme.netUp.opacity(0.05), Theme.netUp.opacity(0.7)],
                                    startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("t", p.time), y: .value("ul", -p.value))
                                .foregroundStyle(Theme.netUp)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: -peak...peak)
                    .frame(height: 60)
                } else {
                    Text("No interfaces")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.overlay0)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        .padding(Theme.panelPadding)
    }
}
