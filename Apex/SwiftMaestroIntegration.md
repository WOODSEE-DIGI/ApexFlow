# SwiftMaestro Integration Guide

This guide shows how to integrate AI Model monitoring into SwiftMaestro using the enhanced `AIModelData` tracking system.

---

## 📊 What Gets Monitored

| Feature | Visual Indicator | Color |
|---------|------------------|-------|
| **Streaming** | Tokens flowing normally | 🟢 Cyan |
| **Connecting** | Request sent, awaiting first token | 🟡 Yellow |
| **Processing** | Silent period (3-60s) | 🟠 Orange/Yellow |
| **Timeout** | Silent > 120s | 🔴 Red |
| **Tool Call Pending** | MCP tool executing | 🟡 Yellow badge |
| **Tool Call Complete** | Tool finished | 🟢 Green badge |

---

## 🔧 Integration Steps

### Step 1: Import AIModelData into SwiftMaestro

In your SwiftMaestro project, import the Apex data models:

```swift
import Foundation
import AIModelData  // Or copy AIModelData.swift into SwiftMaestro
```

### Step 2: Create a Shared Monitor Instance

Add this to your SwiftMaestro AppState or ViewModel:

```swift
@AppStorage("aiModelMonitorEnabled") var aiModelMonitorEnabled = true

// Shared model data instance
let aiModelData = AIModelData()

// System monitor for polling AI processes
let systemMonitor = SystemMonitor.shared
```

### Step 3: Hook Into Chat Request Lifecycle

When you send a message to the AI model, call these methods:

```swift
// Before sending request to Qwen3.5-122B
func sendMessage(_ message: String) async {
    // MARK: Start model request
    aiModelData.startModelRequest()
    
    do {
        let response = try await qwenClient.chat(messages: [message])
        
        // MARK: Receive each token (for streaming responses)
        for try await token in response.stream {
            aiModelData.recordToken()
            
            // Update UI with token
            appendToChat(token)
        }
        
        // MARK: Complete model request
        aiModelData.completeModelRequest()
        
    } catch {
        // Handle error
        print("Chat error: \(error)")
    }
}
```

### Step 4: Hook Into MCP Tool Calls

When SwiftMaestro calls an MCP tool, track it:

```swift
// When MCP tool is invoked
func callMCPTool(name: String, input: [String: Any]) async -> String {
    // MARK: Start tool call tracking
    let toolID = aiModelData.addToolCall(
        name: name,
        input: String(describing: input)
    )
    
    do {
        let result = try await mcpClient.callTool(name: name, input: input)
        
        // MARK: Complete tool call
        let duration = Date().timeIntervalSince(toolCallStartTime)
        aiModelData.completeToolCall(
            id: toolID,
            duration: duration,
            output: result
        )
        
        return result
        
    } catch {
        // MARK: Fail tool call
        aiModelData.failToolCall(id: toolID, error: error.localizedDescription)
        
        throw error
    }
}
```

### Step 5: Connect to SystemMonitor

In your `SystemMonitor` (or create one), add periodic polling:

```swift
// SystemMonitor.swift - Add this method

@MainActor
func startModelResponseMonitoring() {
    Task {
        while true {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            await aiModelData.updateStreamingState()
            
            // Log silent period warnings
            if aiModelData.isSilentProcessing {
                let silentTime = Int(aiModelData.currentResponse.silentDuration)
                
                if silentTime >= 60 {
                    print("⚠️ AI Model silent for \(silentTime)s - possible timeout")
                } else if silentTime >= 30 {
                    print("🔄 AI Model thinking/generating (\(silentTime)s)")
                }
            }
        }
    }
}
```

### Step 6: Display in UI

Add the AIModelView to your SwiftMaestro sidebar or panel:

```swift
// In SwiftMaestro ContentView
struct ContentView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        HStack {
            // Main chat area
            ChatView()
            
            // AI Model Monitor Panel (right sidebar)
            if appState.aiModelMonitorEnabled {
                AIModelView(aiModel: appState.aiModelData)
                    .frame(width: 320)
            }
        }
    }
}
```

---

## 🎯 Example: Full Chat Integration

Here's a complete example of integrating with Qwen3.5-122B streaming:

```swift
@MainActor
class SwiftMaestroChatManager {
    let aiModelData = AIModelData()
    let qwenClient = QwenAPIClient()
    let mcpClient = MCPClient()
    
    func chatWithThinking(_ prompt: String) async {
        // 1. Start model request tracking
        aiModelData.startModelRequest()
        
        var fullResponse = ""
        var toolCalls: [MCPToolCall] = []
        
        do {
            // 2. Send request and stream response
            for try await chunk in await qwenClient.streamChat(prompt) {
                // Record each token received
                aiModelData.recordToken()
                
                if let content = chunk.content {
                    fullResponse += content
                    
                    // Check for tool call requests in response
                    if let toolCall = parseToolCall(from: content) {
                        // Track MCP tool call
                        let toolID = aiModelData.addToolCall(
                            name: toolCall.name,
                            input: toolCall.input
                        )
                        
                        // Execute tool
                        let result = await executeTool(toolCall)
                        
                        // Complete tool call
                        aiModelData.completeToolCall(
                            id: toolID,
                            duration: 5.2,  // Actual duration
                            output: result
                        )
                        
                        toolCalls.append(
                            MCPToolCall(
                                id: toolID,
                                toolName: toolCall.name,
                                status: .completed,
                                duration: 5.2
                            )
                        )
                    }
                }
            }
            
            // 3. Complete model request
            aiModelData.completeModelRequest()
            
        } catch {
            print("Chat error: \(error)")
            // Optionally mark as failed
        }
    }
    
    private func executeTool(_ toolCall: ToolCall) async -> String {
        switch toolCall.name {
        case "filesystem_read":
            return try? await mcpClient.readFile(path: toolCall.input["path"]) ?? "Error"
        case "web_search":
            return try? await mcpClient.searchWeb(query: toolCall.input["query"]) ?? "Error"
        default:
            return "Unknown tool"
        }
    }
}
```

---

## 📋 Quick Reference

### Methods to Call

| When | Call This |
|------|-----------|
| Sending AI request | `aiModelData.startModelRequest()` |
| Receiving each token | `aiModelData.recordToken()` |
| AI response complete | `aiModelData.completeModelRequest()` |
| MCP tool starts | `aiModelData.addToolCall(name: "toolName")` |
| MCP tool finishes | `aiModelData.completeToolCall(id: toolID, duration: seconds)` |
| MCP tool fails | `aiModelData.failToolCall(id: toolID, error: "error msg")` |

### Properties to Display

| Property | Shows |
|----------|-------|
| `aiModelData.tokenActivity.streamingState` | Current state (Idle/Connecting/Streaming/Processing/Timeout) |
| `aiModelData.currentResponse.silentDuration` | Seconds since last token |
| `aiModelData.isSilentProcessing` | True if silent 3-120s (yellow warning) |
| `aiModelData.hasSoftTimeout` | True if silent >= 60s (orange warning) |
| `aiModelData.hasHardTimeout` | True if silent >= 120s (red error) |
| `aiModelData.pendingTools.count` | Number of active MCP tool calls |

---

## 🎨 UI Integration Tips

### Color Coding
```swift
// Streaming state colors
let streamingColors: [TokenActivity.StreamingState: Color] = [
    .idle: .gray,
    .connecting: .yellow,
    .streaming: .cyan,
    .processing: .orange,
    .timeout: .red
]

// Use in your UI
Text("Status: \(aiModelData.tokenActivity.streamingState.rawValue)")
    .foregroundStyle(streamingColors[aiModelData.tokenActivity.streamingState] ?? .gray)
```

### Background Colors for Panels
```swift
// Match panel background to streaming state
let panelBackground: Color = {
    switch aiModelData.tokenActivity.streamingState {
    case .streaming: return Color.cyan.opacity(0.1)
    case .processing: return Color.yellow.opacity(0.1)
    case .timeout: return Color.red.opacity(0.1)
    default: return Color.clear
    }
}()

SomePanel()
    .background(panelBackground)
```

---

## ✅ Testing Checklist

After integration, verify:

- [ ] Status badge changes when sending request (Idle → Connecting)
- [ ] Status turns Streaming when tokens arrive
- [ ] "🔄 MODEL THINKING" appears during silent periods
- [ ] "⚠️ SLOW RESPONSE" appears after 60s silent
- [ ] "⚠️ HARD TIMEOUT" appears after 120s silent
- [ ] MCP tool calls show as pending badges
- [ ] Tool call duration displays after completion
- [ ] AI processes list shows CPU/memory usage

---

## 🚀 Next Steps

1. **Copy files into SwiftMaestro**:
   - `AIModelData.swift` → SwiftMaestro/Models/
   - `AIModelView.swift` → SwiftMaestro/Views/
   - `SystemMonitor.swift` (enhanced version) → SwiftMaestro/Services/

2. **Update AppState** to include `aiModelData` and call tracking methods

3. **Add AIModelView** to SwiftMaestro sidebar panel

4. **Test with real Qwen3.5-122B requests** to verify monitoring works

---

## 📞 Support

If you encounter issues:
1. Check console logs for silent period warnings
2. Verify `startModelRequest()` and `recordToken()` are being called
3. Ensure `AIModelData` is `@MainActor` and accessed on main thread
4. Check that `SystemMonitor` polling is enabled

---

*Created for SwiftMaestro + Apex Flow integration*
FILEEOF ; echo "__SWIFTMAESTRO_CWD__=$(pwd)"