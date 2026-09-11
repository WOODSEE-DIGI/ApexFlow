import Foundation
import Observation

struct ProcessSnapshot: Sendable, Identifiable {
    let id: Int32  // pid
    let ppid: Int32
    let name: String
    let user: String
    let cpuPercent: Double
    let memoryBytes: UInt64
    let threads: Int
    let status: String
}

@Observable
@MainActor
final class ProcessData {
    var processes: [ProcessSnapshot] = []
    var filter: String = ""
    var sortKey: SortKey = .cpu
    var sortAscending: Bool = false

    enum SortKey: String, CaseIterable {
        case pid = "PID"
        case name = "Name"
        case cpu = "CPU%"
        case memory = "Memory"
        case threads = "Threads"
        case user = "User"
    }

    func update(from snapshots: [ProcessSnapshot]) {
        processes = sorted(snapshots)
    }

    var filtered: [ProcessSnapshot] {
        guard !filter.isEmpty else { return processes }
        return processes.filter {
            $0.name.localizedCaseInsensitiveContains(filter) ||
            $0.user.localizedCaseInsensitiveContains(filter) ||
            String($0.id).contains(filter)
        }
    }

    private func sorted(_ list: [ProcessSnapshot]) -> [ProcessSnapshot] {
        list.sorted { a, b in
            let result: Bool
            switch sortKey {
            case .pid:     result = a.id < b.id
            case .name:    result = a.name < b.name
            case .cpu:     result = a.cpuPercent > b.cpuPercent
            case .memory:  result = a.memoryBytes > b.memoryBytes
            case .threads: result = a.threads > b.threads
            case .user:    result = a.user < b.user
            }
            return sortAscending ? !result : result
        }
    }
}
