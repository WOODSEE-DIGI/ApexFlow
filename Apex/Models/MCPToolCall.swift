import Foundation

// MARK: - MCP Tool Call Tracking
/// MCP Tool call tracking with detailed diagnostics
struct MCPToolCall: Identifiable, Hashable {
    let id: String                  // Unique tool call ID
    let timestamp: Date
    let toolName: String
    var status: ToolStatus
    var duration: TimeInterval?
    let input: String?              // Tool input (for debugging)
    var output: String?             // Tool output (for debugging)
    var error: String?              // Error message if failed
    
    enum ToolStatus: String {
        case pending = "pending"
        case completed = "completed"
        case failed = "failed"
        case cancelled = "cancelled"
    }
    
    init(id: String = UUID().uuidString, timestamp: Date = .now, toolName: String, status: ToolStatus, duration: TimeInterval? = nil, input: String? = nil, output: String? = nil, error: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.toolName = toolName
        self.status = status
        self.duration = duration
        self.input = input
        self.output = output
        self.error = error
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MCPToolCall, rhs: MCPToolCall) -> Bool {
        lhs.id == rhs.id
    }
}