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
    let isAI: Bool          // True if this is an AI model/MCP/daemon/child
    let aiRole: String?     // Short label for the AI role (e.g. "MCP", "Daemon")
}

@Observable
@MainActor
final class ProcessData {
    var processes: [ProcessSnapshot] = []
    var filter: String = ""
    var sortKey: SortKey = .cpu
    var sortAscending: Bool = false
    var aiPIDs: Set<Int32> = []
    var aiRoles: [Int32: String] = [:]

    enum SortKey: String, CaseIterable {
        case pid = "PID"
        case name = "Name"
        case cpu = "CPU%"
        case memory = "Memory"
        case threads = "Threads"
        case user = "User"
    }

    func update(from snapshots: [ProcessSnapshot], aiPIDs: Set<Int32> = [], aiRoles: [Int32: String] = [:]) {
        processes = sorted(snapshots)
        self.aiPIDs = aiPIDs
        self.aiRoles = aiRoles
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
