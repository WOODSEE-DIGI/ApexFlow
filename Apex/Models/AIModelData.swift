import Foundation
import Observation

// MARK: - AI Model Snapshot
/// Represents an AI model process being monitored
struct AIModelSnapshot: Identifiable, Hashable {
    let id: Int32               // PID
    let parentPID: Int32?       // Parent PID (for spotting spawned daemons/MCP servers)
    let name: String            // Process name (e.g., "LM Studio", "ollama")
    let commandLine: String?    // Full command line used for classification
    let cpuPercent: Double      // CPU usage percentage
    let memoryBytes: UInt64     // Memory usage in bytes
    let threads: Int            // Thread count
    let status: ProcessStatus   // Process state
    let kind: ProcessKind       // AI-related role (model engine, MCP server, daemon, online)
    let ports: [Int]            // TCP ports this process is listening on
    
    enum ProcessStatus: String, Codable {
        case running = "Running"
        case sleeping = "Sleeping"
        case idle = "Idle"
        case stopped = "Stopped"
        case zombie = "Zombie"
        
        var color: String {
            switch self {
            case .running: return "active"
            case .sleeping: return "idle"
            case .idle: return "idle"
            case .stopped: return "warning"
            case .zombie: return "error"
            }
        }
    }
    
    enum ProcessKind: String, Codable, Sendable {
        case modelEngine = "Model"
        case mcpServer = "MCP"
        case daemon = "Daemon"
        case onlineService = "Online"
        case helper = "Helper"
        case unknown = "AI"

        var label: String { rawValue }

        var colorName: String {
            switch self {
            case .modelEngine:   return "sky"
            case .mcpServer:     return "mauve"
            case .daemon:        return "peach"
            case .onlineService: return "blue"
            case .helper:        return "teal"
            case .unknown:       return "subtext1"
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AIModelSnapshot, rhs: AIModelSnapshot) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Token Activity Tracking
/// Token activity tracking for an AI model process
struct TokenActivity {
    var lastTokenTime: Date         // When last token was received
    var tokensPerSecond: Double     // Current token generation rate
    var totalTokens: Int            // Total tokens processed
    var isIdle: Bool                // True if no tokens in recent period
    var hasTimedOut: Bool           // True if exceeded timeout threshold
    var streamingState: StreamingState  // Current streaming state
    
    enum StreamingState: String {
        case idle = "Idle"
        case connecting = "Connecting"
        case streaming = "Streaming"
        case processing = "Processing"  // Model thinking/generating (silent period)
        case timeout = "Timeout"
        
        var color: String {
            switch self {
            case .idle: return "overlay0"
            case .connecting: return "yellow"
            case .streaming: return "cyan"
            case .processing: return "yellow"  // Yellow = waiting for model response
            case .timeout: return "red"
            }
        }
    }
    
    init() {
        self.lastTokenTime = .now
        self.tokensPerSecond = 0
        self.totalTokens = 0
        self.isIdle = false
        self.hasTimedOut = false
        self.streamingState = .idle
    }
}

// MARK: - Model Response Tracking
/// Tracks the state of AI model responses for timeout detection
struct ModelResponseState {
    var requestStartTime: Date?     // When the request was sent
    var firstTokenTime: Date?       // When first token arrived
    var lastTokenTime: Date?        // When last token arrived
    var isAwaitingResponse: Bool    // True after sending request, before first token
    var hasReceivedTokens: Bool     // True if any tokens received
    
    var silentDuration: TimeInterval {
        guard let last = lastTokenTime else { return 0 }
        return Date().timeIntervalSince(last)
    }
    
    var requestDuration: TimeInterval {
        guard let start = requestStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    mutating func startRequest() {
        requestStartTime = Date()
        firstTokenTime = nil
        lastTokenTime = nil
        isAwaitingResponse = true
        hasReceivedTokens = false
    }
    
    mutating func recordToken() {
        if firstTokenTime == nil {
            firstTokenTime = Date()
        }
        lastTokenTime = Date()
        hasReceivedTokens = true
        isAwaitingResponse = false
    }
    
    mutating func completeRequest() {
        isAwaitingResponse = false
    }
    
    init() {
        self.requestStartTime = nil
        self.firstTokenTime = nil
        self.lastTokenTime = nil
        self.isAwaitingResponse = false
        self.hasReceivedTokens = false
    }
}

@Observable
@MainActor
final class AIModelData {
    // MARK: - Process monitoring
    var aiProcesses: [AIModelSnapshot] = []
    var selectedPID: Int32?           // Currently selected AI process
    
    // MARK: - Token activity tracking
    var tokenActivity: TokenActivity = TokenActivity()
    var tokenHistory: [(time: Date, count: Int)] = []  // Last 60 seconds
    
    // MARK: - MCP Tool tracking
    var recentToolCalls: [MCPToolCall] = []
    var pendingTools: Set<String> = []  // Tool IDs that are pending
    
    // MARK: - Model response tracking
    var currentResponse: ModelResponseState = ModelResponseState()
    
    // MARK: - Broadcast source
    /// The name of the app currently broadcasting token data (e.g. "SwiftMaestro").
    var broadcastingAppName: String = ""
    
    // MARK: - Configuration
    var idleTimeoutThreshold: TimeInterval = 30.0   // Seconds before marked as idle
    var softTimeoutThreshold: TimeInterval = 60.0   // Warning threshold for silent periods
    var hardTimeoutThreshold: TimeInterval = 120.0  // Seconds before marked as timeout
    var monitoredProcessNames: [String] = [
        "LM Studio", "ollama", "SwiftMaestro", "llama-server", "text-generation-webui",
        "vllm", "aiserver", "open-webui", "anything-llm"
    ]
    
    // MARK: - Internal state
    private var previousTokenCount: Int = 0
    private var lastTokenTimestamp: Date = .now
    
    // MARK: - Process updates
    func updateProcesses(from snapshots: [AIModelSnapshot]) {
        aiProcesses = snapshots
    }
    
    // MARK: - Token tracking
    
    /// Record a new token received (call this when tokens stream in)
    func recordToken() {
        let now = Date()
        tokenActivity.totalTokens += 1
        
        // Calculate tokens per second over a 1-second window
        let elapsed = now.timeIntervalSince(lastTokenTimestamp)
        if elapsed >= 1.0 {
            let delta = tokenActivity.totalTokens - previousTokenCount
            tokenActivity.tokensPerSecond = Double(delta) / elapsed
            previousTokenCount = tokenActivity.totalTokens
            lastTokenTimestamp = now
            
            // Add to history (keep last 60 entries)
            tokenHistory.append((now, tokenActivity.totalTokens))
            if tokenHistory.count > 60 {
                tokenHistory.removeFirst()
            }
        }
        
        // Update response state
        currentResponse.recordToken()
        
        // Update streaming state
        updateStreamingState()
        
        // Update idle/timeout status
        updateActivityStatus()
    }
    
    // MARK: - Request lifecycle
    
    /// Call when sending a request to the AI model
    func startModelRequest() {
        currentResponse.startRequest()
        tokenActivity.streamingState = .connecting
    }
    
    /// Call when receiving first token from model
    func receivedFirstToken() {
        updateStreamingState()
    }
    
    /// Call when model response is complete
    func completeModelRequest() {
        currentResponse.completeRequest()
        if tokenActivity.tokensPerSecond == 0 {
            tokenActivity.streamingState = .idle
        }
    }
    
    // MARK: - MCP Tool tracking
    
    /// Add an MCP tool call to tracking
    func addToolCall(name: String, toolID: String? = nil, input: String? = nil) -> String {
        let id = toolID ?? UUID().uuidString
        let call = MCPToolCall(id: id, timestamp: .now, toolName: name, status: .pending, input: input)
        recentToolCalls.insert(call, at: 0)
        pendingTools.insert(id)
        
        // Keep only recent 100 calls
        if recentToolCalls.count > 100 {
            recentToolCalls.removeLast(100)
        }
        
        return id
    }
    
    /// Mark a tool call as completed
    func completeToolCall(id: String, duration: TimeInterval, output: String? = nil) {
        if let index = recentToolCalls.firstIndex(where: { $0.id == id && $0.status == .pending }) {
            recentToolCalls[index].status = .completed
            recentToolCalls[index].duration = duration
            recentToolCalls[index].output = output
        }
        pendingTools.remove(id)
    }
    
    /// Mark a tool call as failed
    func failToolCall(id: String, error: String) {
        if let index = recentToolCalls.firstIndex(where: { $0.id == id && $0.status == .pending }) {
            recentToolCalls[index].status = .failed
            recentToolCalls[index].error = error
            recentToolCalls[index].duration = Date().timeIntervalSince(recentToolCalls[index].timestamp)
        }
        pendingTools.remove(id)
    }
    
    /// Cancel a tool call
    func cancelToolCall(id: String) {
        if let index = recentToolCalls.firstIndex(where: { $0.id == id && $0.status == .pending }) {
            recentToolCalls[index].status = .cancelled
            recentToolCalls[index].duration = Date().timeIntervalSince(recentToolCalls[index].timestamp)
        }
        pendingTools.remove(id)
    }
    
    // MARK: - Status checks
    
    /// Check if AI model is currently active (receiving tokens)
    var isActive: Bool {
        let idleTime = Date().timeIntervalSince(tokenActivity.lastTokenTime)
        return idleTime < idleTimeoutThreshold
    }
    
    /// Check if AI model has exceeded soft timeout (warning)
    var hasSoftTimeout: Bool {
        let idleTime = Date().timeIntervalSince(tokenActivity.lastTokenTime)
        return idleTime >= softTimeoutThreshold && idleTime < hardTimeoutThreshold
    }
    
    /// Check if AI model has exceeded hard timeout (error)
    var hasHardTimeout: Bool {
        let idleTime = Date().timeIntervalSince(tokenActivity.lastTokenTime)
        return idleTime >= hardTimeoutThreshold
    }
    
    /// Check if model is in a silent/processing period (no tokens but not yet timeout)
    var isSilentProcessing: Bool {
        guard currentResponse.isAwaitingResponse || (currentResponse.hasReceivedTokens && !currentResponse.isAwaitingResponse) else { return false }
        let silentTime = currentResponse.silentDuration
        return silentTime >= 3.0 && silentTime < hardTimeoutThreshold
    }
    
    /// Get current AI model process (if any)
    var activeAIProcess: AIModelSnapshot? {
        guard let selectedPID = selectedPID else { return nil }
        return aiProcesses.first { $0.id == selectedPID }
    }
    
    /// Get AI process by PID
    func getProcess(pid: Int32) -> AIModelSnapshot? {
        aiProcesses.first { $0.id == pid }
    }
    
    /// Get pending tool calls (tools currently executing)
    var activeToolCalls: [MCPToolCall] {
        recentToolCalls.filter { $0.status == .pending }
    }
    
    /// Get total pending tool count
    var pendingToolCount: Int {
        pendingTools.count
    }
    
    // MARK: - Internal helpers
    
    private func updateStreamingState() {
        if currentResponse.isAwaitingResponse {
            tokenActivity.streamingState = .connecting
        } else if currentResponse.hasReceivedTokens && !currentResponse.isAwaitingResponse {
            tokenActivity.streamingState = .streaming
        } else if !isActive && currentResponse.hasReceivedTokens {
            tokenActivity.streamingState = .processing
        } else if hasHardTimeout {
            tokenActivity.streamingState = .timeout
        } else {
            tokenActivity.streamingState = .idle
        }
    }
    
    func updateActivityStatus() {
        let idleTime = Date().timeIntervalSince(tokenActivity.lastTokenTime)
        
        tokenActivity.isIdle = idleTime >= idleTimeoutThreshold
        tokenActivity.hasTimedOut = idleTime >= hardTimeoutThreshold
        
        // Update streaming state based on activity
        updateStreamingState()
    }
}