import SwiftUI

// MARK: - Apex Panel Content View
/// Resolves an `ApexPanelKind` to the existing Apex monitor view.
struct ApexPanelContentView: View {
    let kind: ApexPanelKind
    let monitor: SystemMonitor

    var body: some View {
        switch kind {
        case .cpu:
            CPUView(cpu: monitor.cpu)
        case .memory:
            MemoryView(memory: monitor.memory, disk: monitor.disk)
        case .network:
            NetworkView(network: monitor.network)
        case .connectivity:
            ConnView(conn: monitor.conn)
        case .aiModel:
            AIModelView(aiModel: monitor.aiModel)
        case .processes:
            ProcessView(processes: monitor.processes)
        case .diskHealth:
            DiskHealthView(disk: monitor.disk)
        }
    }
}
