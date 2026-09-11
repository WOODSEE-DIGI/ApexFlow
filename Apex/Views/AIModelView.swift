import SwiftUI

struct AIModelView: View {
    let aiModel: AIModelData
    
    var body: some View {
        VStack(spacing: 6) {
                // Token Activity Header with Enhanced State Indicators
                TokenActivityView(tokenActivity: aiModel.tokenActivity,
                                  broadcastingAppName: aiModel.broadcastingAppName,
                                  isActive: aiModel.isActive,
                                  hasSoftTimeout: aiModel.hasSoftTimeout,
                                  hasHardTimeout: aiModel.hasHardTimeout,
                                  isSilentProcessing: aiModel.isSilentProcessing,
                                  silentDuration: aiModel.currentResponse.silentDuration,
                                  idleTimeoutThreshold: aiModel.idleTimeoutThreshold,
                                  softTimeoutThreshold: aiModel.softTimeoutThreshold,
                                  hardTimeoutThreshold: aiModel.hardTimeoutThreshold)
                
                Divider().background(Theme.surface1)
                
                // AI Process List
                if !aiModel.aiProcesses.isEmpty {
                    AIProcessListView(aiModel: aiModel)
                } else {
                    EmptyAIProcessView()
                }
                
                Divider().background(Theme.surface1)
                
                // MCP Tool Calls (recent)
                MCPToolCallView(toolCalls: aiModel.recentToolCalls,
                                pendingTools: aiModel.pendingTools)
            }
        .padding(Theme.panelPadding)
    }
}

// MARK: - Token Activity View (Enhanced with Streaming States)
private struct TokenActivityView: View {
    let tokenActivity: TokenActivity
    let broadcastingAppName: String
    let isActive: Bool
    let hasSoftTimeout: Bool
    let hasHardTimeout: Bool
    let isSilentProcessing: Bool
    let silentDuration: TimeInterval
    let idleTimeoutThreshold: TimeInterval
    let softTimeoutThreshold: TimeInterval
    let hardTimeoutThreshold: TimeInterval
    
    var body: some View {
        VStack(spacing: 6) {
            // Status Header Row
            HStack(spacing: 12) {
                // Enhanced Status Indicator with Streaming State
                ZStack {
                    Circle()
                        .fill(currentStateColor)
                        .frame(width: 12, height: 12)
                    
                    // Pulsing ring for active streaming
                    if tokenActivity.streamingState == .streaming {
                        Circle()
                            .stroke(currentStateColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .scaleEffect(1.5)
                            .opacity(Double(silentDuration / 10.0).clamped(to: 0...1))
                    }
                    
                    Circle()
                        .stroke(currentStateColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Main metrics row
                    HStack(spacing: 10) {
                        Text("Tokens/sec")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.text)
                        
                        Text(String(format: "%.1f", tokenActivity.tokensPerSecond))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(tokenCountColor)
                        
                        Text("Total: \(tokenActivity.totalTokens)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.overlay1)
                        
                        // Show which app is broadcasting
                        if !broadcastingAppName.isEmpty {
                            Text("@ \(broadcastingAppName)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.blue)
                        }
                    }
                    
                    // Silent period / Timeout warning row
                    HStack(spacing: 8) {
                        if isSilentProcessing || hasSoftTimeout || hasHardTimeout {
                            // Silent period indicator with explanation
                            Text(silentPeriodLabel)
                                .font(.system(size: 9, weight: hasHardTimeout ? .bold : .semibold, design: .monospaced))
                                .foregroundStyle(silentPeriodColor)
                                .help(silentPeriodHelp)
                            
                            // Silent duration
                            Text("Idle: \(Int(silentDuration))s")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(silentDurationColor)
                        } else {
                            // Normal idle timer
                            let idleSeconds = Int(Date().timeIntervalSince(tokenActivity.lastTokenTime))
                            Text("Idle: \(idleSeconds)s")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(idleTimerColor)
                        }
                        
                        // Thresholds reference
                        Text("Thresholds: \(Int(idleTimeoutThreshold))s / \(Int(softTimeoutThreshold))s / \(Int(hardTimeoutThreshold))s")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Theme.overlay0)
                    }
                }
                
                Spacer()
                
                // Streaming State Badge
                StreamingStateBadge(state: tokenActivity.streamingState)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
    
    // MARK: - Computed Properties
    
    private var currentStateColor: Color {
        switch tokenActivity.streamingState {
        case .idle: return Theme.overlay0
        case .connecting: return Theme.yellow
        case .streaming: return Theme.sky
        case .processing: return Theme.yellow
        case .timeout: return Theme.red
        }
    }
    
    private var tokenCountColor: Color {
        switch tokenActivity.streamingState {
        case .idle: return Theme.overlay1
        case .connecting: return Theme.yellow
        case .streaming: return Theme.sky
        case .processing: return Theme.yellow
        case .timeout: return Theme.red
        }
    }
    
    private var silentPeriodLabel: String {
        if hasHardTimeout {
            return "⚠️ NO RESPONSE (\(Int(silentDuration))s)"
        } else if hasSoftTimeout {
            return "⚠️ SLOW RESPONSE (\(Int(silentDuration))s)"
        } else if isSilentProcessing {
            return "🧠 MODEL THINKING"
        } else {
            return ""
        }
    }
    
    private var silentPeriodHelp: String {
        if hasHardTimeout {
            return "No tokens received for \(Int(silentDuration))s. The model may be stuck or overloaded."
        } else if hasSoftTimeout {
            return "Response is slow (\(Int(silentDuration))s idle). The model may be processing a complex request."
        } else {
            return "Model is generating a response silently (thinking/planning)."
        }
    }
    
    private var silentPeriodColor: Color {
        if hasHardTimeout { return Theme.red }
        if hasSoftTimeout { return Theme.peach }
        return Theme.yellow
    }
    
    private var silentDurationColor: Color {
        if silentDuration >= 120 { return Theme.red }
        if silentDuration >= 60 { return Theme.peach }
        if silentDuration >= 30 { return Theme.yellow }
        return Theme.overlay1
    }
    
    private var idleTimerColor: Color {
        let idleTime = Date().timeIntervalSince(tokenActivity.lastTokenTime)
        if idleTime >= 120 { return Theme.red }
        if idleTime >= 30 { return Theme.yellow }
        return Theme.overlay1
    }
    
    private var backgroundColor: Color {
        switch tokenActivity.streamingState {
        case .streaming: return Theme.sky.opacity(0.1)
        case .processing: return Theme.yellow.opacity(0.1)
        case .timeout: return Theme.red.opacity(0.1)
        case .connecting: return Theme.yellow.opacity(0.05)
        case .idle: return Theme.surface1.opacity(0.3)
        }
    }
}

// MARK: - Streaming State Badge
private struct StreamingStateBadge: View {
    let state: TokenActivity.StreamingState
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: stateIcon)
                .font(.system(size: 10, weight: .semibold))
            
            Text(state.rawValue)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(stateBadgeColor.opacity(0.2))
        .foregroundStyle(stateBadgeColor)
        .clipShape(Capsule())
    }
    
    private var stateIcon: String {
        switch state {
        case .idle: return "stop.circle"
        case .connecting: return "arrow.clockwise"
        case .streaming: return "play.circle.fill"
        case .processing: return "hourglass"
        case .timeout: return "exclamationmark.triangle.fill"
        }
    }
    
    private var stateBadgeColor: Color {
        switch state {
        case .idle: return Theme.overlay0
        case .connecting: return Theme.yellow
        case .streaming: return Theme.sky
        case .processing: return Theme.peach
        case .timeout: return Theme.red
        }
    }
}

// MARK: - AI Process List View
private struct AIProcessListView: View {
    let aiModel: AIModelData
    
    var body: some View {
        VStack(spacing: 4) {
            // Header row — must match data row frame structure exactly
            HStack(spacing: 0) {
                Text("PID")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
                    .frame(width: 50, alignment: .leading)
                
                Text("Name")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("CPU%")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
                    .frame(width: 50, alignment: .leading)
                
                Text("Memory")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
                    .frame(width: 70, alignment: .leading)
                
                Text("Status")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
                    .frame(width: 80, alignment: .leading)
            }
            .padding(.horizontal, 6)
            
            Divider().background(Theme.surface1)
            
            // Process list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 1) {
                    ForEach(aiModel.aiProcesses) { proc in
                        AIProcessRow(proc: proc, isSelected: aiModel.selectedPID == proc.id)
                            .onTapGesture {
                                aiModel.selectedPID = proc.id
                            }
                    }
                }
            }
        }
    }
}

private struct AIProcessRow: View {
    let proc: AIModelSnapshot
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Text("\(proc.id)")
                .frame(width: 50, alignment: .leading)
            
            Text(proc.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(String(format: "%.1f", proc.cpuPercent))
                .foregroundStyle(Theme.loadColor(proc.cpuPercent / 100))
                .frame(width: 50, alignment: .leading)
            
            Text(proc.memoryBytes.formattedBytes)
                .frame(width: 70, alignment: .leading)
            
            Text(proc.status.rawValue)
                .foregroundStyle(statusColor)
                .frame(width: 80, alignment: .leading)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(isSelected ? Theme.blue : Theme.subtext1)
        .padding(.vertical, 1)
        .background(isSelected ? Theme.surface1.opacity(0.3) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private var statusColor: Color {
        switch proc.status {
        case .running: return Theme.green
        case .sleeping, .idle: return Theme.overlay1
        case .stopped: return Theme.yellow
        case .zombie: return Theme.red
        }
    }
}

private struct EmptyAIProcessView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 24))
                .foregroundStyle(Theme.overlay0)
            
            Text("No AI processes detected")
                .font(.system(size: 11))
                .foregroundStyle(Theme.overlay1)
            
            Text("Start LM Studio, ollama, or other AI services")
                .font(.system(size: 9))
                .foregroundStyle(Theme.overlay0)
            
            Text("Token data may still arrive via SwiftMaestro notifications")
                .font(.system(size: 8))
                .foregroundStyle(Theme.overlay0)
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - MCP Tool Call View (Enhanced)
private struct MCPToolCallView: View {
    let toolCalls: [MCPToolCall]
    let pendingTools: Set<String>
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Recent Tool Calls")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.overlay0)
                
                Spacer()
                
                if !pendingTools.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView(value: Double(pendingTools.count))
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .foregroundStyle(Theme.yellow)
                        
                        Text("\(pendingTools.count) active")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.yellow)
                    }
                }
            }
            .padding(.horizontal, 6)
            
            Divider().background(Theme.surface1)
            
            // Tool call list (last 5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(toolCalls.prefix(5), id: \.timestamp) { call in
                        ToolCallBadge(call: call)
                    }
                    
                    if toolCalls.isEmpty {
                        Text("No tool calls yet")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.overlay1)
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
    }
}

private struct ToolCallBadge: View {
    let call: MCPToolCall
    
    var body: some View {
        HStack(spacing: 4) {
            Text(call.toolName)
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
            
            Image(systemName: statusIcon)
                .font(.system(size: 8))
            
            // Duration if available
            if let duration = call.duration {
                Text(String(format: "%.0fs", duration))
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(durationColor)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusBackgroundColor.opacity(0.3))
        .clipShape(Capsule())
        .foregroundStyle(statusTextColor)
    }
    
    private var statusIcon: String {
        switch call.status {
        case .pending: return "clock"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }
    
    private var statusBackgroundColor: Color {
        switch call.status {
        case .pending: return Theme.yellow
        case .completed: return Theme.green
        case .failed: return Theme.red
        case .cancelled: return Theme.overlay0
        }
    }
    
    private var statusTextColor: Color {
        switch call.status {
        case .pending: return Theme.yellow
        case .completed: return Theme.green
        case .failed: return Theme.red
        case .cancelled: return Theme.overlay0
        }
    }
    
    private var durationColor: Color {
        if let dur = call.duration {
            if dur >= 60 { return Theme.red }
            if dur >= 30 { return Theme.peach }
            return Theme.overlay1
        }
        return Theme.overlay1
    }
}

// MARK: - Helper Extensions

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

