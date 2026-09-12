import Darwin
import Foundation
import AppKit

// MARK: - AI Model Collector

/// Scans for actually-running AI model processes on the system (SwiftMaestro,
/// LM Studio, ollama, llama-server, etc.) and returns their live resource usage.
final actor AIModelCollector {

    /// Process names to watch for (lowercased for case-insensitive matching).
    /// These are checked against the executable basename AND the full command line.
    private static let watchedProcessNames: Set<String> = [
        "swiftmaestro", "lm studio", "ollama", "llama-server",
        "llama.cpp", "vllm", "text-generation-webui", "gpt4all",
        "open-webui", "anything-llm", "localai", "koboldcpp",
        "lmstudio", "inference", "omlx", "deltafin",
        "vision_proxy_server", "modelmanagerd", "siriinferenced",
        "tgondeviceinferenceproviderservice"
    ]

    /// Command-line tokens that strongly indicate an MCP server.
    private static let mcpMarkers: Set<String> = [
        "mcp-server", "mcp_server", "swiftmaestro-mcp", "mcp-servers",
        "--mcp", "@modelcontextprotocol"
    ]

    /// Tokens that indicate a local/online model inference engine.
    private static let modelEngineMarkers: Set<String> = [
        "--model", ".gguf", "mlx", "omlx", "llama-server", "llama.cpp",
        "ollama", "lm studio", "lmstudio", "vllm", "text-generation-webui",
        "gpt4all", "open-webui", "anything-llm", "localai", "koboldcpp",
        "swiftmaestro", "deltafin", "vision_proxy", "modelmanagerd",
        "siriinferenced", "tgondeviceinferenceproviderservice"
    ]

    /// Host substrings that indicate a connection to an online AI service.
    private static let onlineServiceHosts: Set<String> = [
        "api.openai.com", "api.anthropic.com", "generativelanguage.googleapis.com",
        "api.groq.com", "api.together.xyz", "api.perplexity.ai",
        "api.mistral.ai", "api.cohere.com", "api.ai21.com",
        "openrouter.ai", "api.replicate.com", "api.deepseek.com"
    ]

    /// Xcode-launched apps get truncated args like "-NSDocumentRevisionsDebugMode YES".
    /// This flag is passed by Xcode to every debug-launched app.
    private static let xcodeLaunchMarker = "-NSDocumentRevisionsDebugMode"

    // MARK: - Public

    func collect() async -> [AIModelSnapshot] {
        let allProcesses = processList()
        let listeningPorts = portMap()

        // First pass: identify processes that are AI-related by their own name/cmdline.
        var aiPIDs = Set<Int32>()
        for process in allProcesses {
            if isAIProcess(process) {
                aiPIDs.insert(process.pid)
            }
        }

        var snapshots = [AIModelSnapshot]()
        var nameCounts: [String: Int] = [:]

        for process in allProcesses {
            let lowerName = process.name.lowercased()
            let cl = process.commandLine ?? ""

            // Include direct AI processes and children spawned by them (MCP servers, helpers).
            let isDirectAI = isAIProcess(process)
            let isChildOfAI = aiPIDs.contains(process.parentPID)
            let isXcodeLaunch = cl.hasPrefix("-NSDocument")
                || cl.hasPrefix("-NS")
                || cl == Self.xcodeLaunchMarker

            guard isDirectAI || isChildOfAI || isXcodeLaunch else { continue }

            let displayName: String
            if isXcodeLaunch {
                displayName = resolveAppName(pid: process.pid) ?? resolveProcessName(
                    baseName: process.name,
                    commandLine: cl
                )
            } else {
                displayName = resolveProcessName(
                    baseName: process.name,
                    commandLine: cl
                )
            }

            // Disambiguate duplicate names
            let key = displayName
            let finalName: String
            if nameCounts[key, default: 0] > 0 {
                finalName = "\(displayName) (\(nameCounts[key]!))"
            } else {
                finalName = displayName
            }
            nameCounts[key, default: 0] += 1

            let kind = classify(process: process, isChildOfAI: isChildOfAI)
            let status = status(from: process.state)

            snapshots.append(AIModelSnapshot(
                id: process.pid,
                parentPID: process.parentPID,
                name: finalName,
                commandLine: cl,
                cpuPercent: process.cpuPercent,
                memoryBytes: process.residentMemoryBytes,
                threads: 0,
                status: status,
                kind: kind,
                ports: listeningPorts[process.pid] ?? []
            ))
        }

        return snapshots.sorted { $0.name < $1.name }
    }

    private func isAIProcess(_ process: ProcessInfo) -> Bool {
        let lowerName = process.name.lowercased()
        let isWatched = Self.watchedProcessNames.contains { lowerName.contains($0) }
        let cl = process.commandLine ?? ""
        let looksLikeModelServer = Self.modelEngineMarkers.contains { marker in
            lowerName.contains(marker) || cl.lowercased().contains(marker)
        }
        return isWatched || looksLikeModelServer
    }

    private func classify(process: ProcessInfo, isChildOfAI: Bool) -> AIModelSnapshot.ProcessKind {
        let lowerName = process.name.lowercased()
        let cl = process.commandLine?.lowercased() ?? ""

        if Self.mcpMarkers.contains(where: { lowerName.contains($0) || cl.contains($0) }) {
            return .mcpServer
        }
        if isOnlineService(process) {
            return .onlineService
        }
        if Self.modelEngineMarkers.contains(where: { lowerName.contains($0) || cl.contains($0) }) {
            return .modelEngine
        }
        if isChildOfAI {
            return process.name.hasSuffix("d") ? .daemon : .helper
        }
        return .unknown
    }

    private func isOnlineService(_ process: ProcessInfo) -> Bool {
        // Quick heuristic: a node/Python helper that connects to a known AI API host.
        let cl = process.commandLine?.lowercased() ?? ""
        let genericHosts = Self.onlineServiceHosts.contains { cl.contains($0) }
        let genericExecutables = ["node", "python", "python3", "application"].contains(process.name.lowercased())
        return genericHosts && genericExecutables
    }

    private func status(from state: String) -> AIModelSnapshot.ProcessStatus {
        switch state {
        case "R":  return .running
        case "S":  return .sleeping
        case "T":  return .stopped
        case "Z":  return .zombie
        default:   return .idle
        }
    }

    // MARK: - Process Scanning

    private struct ProcessInfo {
        let pid: Int32
        let parentPID: Int32
        let name: String
        let state: String       // R, S, T, Z, etc.
        let cpuPercent: Double
        let residentMemoryBytes: UInt64
        let commandLine: String?
    }

    /// Uses `ps` to get all processes with parent PID, CPU%, memory, state, and command line.
    /// NOTE: We intentionally skip the `comm` column because macOS truncates it
    /// to 15 characters (e.g. "SwiftMaestro" → "SwiftMaest"), making name
    /// matching impossible. Instead we parse the executable basename from `args`.
    private func processList() -> [ProcessInfo] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        // ppid lets us spot MCP servers / daemons spawned by a model host.
        task.arguments = ["-eo", "pid,ppid,stat,%cpu,rss,args"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return []
        }

        // IMPORTANT: Read pipe data BEFORE waitUntilExit() to avoid deadlock.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return [] }

        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var results = [ProcessInfo]()
        var firstLine = true

        for line in output.components(separatedBy: .newlines) {
            if firstLine { firstLine = false; continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse: PID PPID STAT %CPU RSS ARGS...
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 6 else { continue }

            guard let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1]) else { continue }
            let state = parts[2]
            let cpuPercent = Double(parts[3]) ?? 0
            let rssKB = UInt64(parts[4]) ?? 0

            // Reconstruct args string (everything after RSS).
            var fieldEnd = trimmed.startIndex
            var fieldCount = 0
            while fieldEnd < trimmed.endIndex && fieldCount < 5 {
                while fieldEnd < trimmed.endIndex && !trimmed[fieldEnd].isWhitespace {
                    fieldEnd = trimmed.index(after: fieldEnd)
                }
                while fieldEnd < trimmed.endIndex && trimmed[fieldEnd].isWhitespace {
                    fieldEnd = trimmed.index(after: fieldEnd)
                }
                fieldCount += 1
            }
            let commandLine = String(trimmed[fieldEnd...])
            guard !commandLine.isEmpty else { continue }

            // Extract executable basename from the command line.
            let execName: String
            if let spaceIdx = commandLine.firstIndex(of: " ") {
                execName = String(commandLine[commandLine.startIndex..<spaceIdx])
            } else {
                execName = commandLine
            }
            let baseName = (execName as NSString).lastPathComponent

            results.append(ProcessInfo(
                pid: pid,
                parentPID: ppid,
                name: baseName,
                state: state,
                cpuPercent: cpuPercent,
                residentMemoryBytes: rssKB * 1024,
                commandLine: commandLine
            ))
        }

        return results
    }

    // MARK: - Listening Port Discovery

    /// Map PID -> TCP listen ports by parsing `lsof -iTCP -sTCP:LISTEN`.
    /// This lets us show that LM Studio is serving on :1234, ollama on :11434, etc.
    private func portMap() -> [Int32: [Int]] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else { return [:] }

        var map: [Int32: [Int]] = [:]
        for line in output.components(separatedBy: .newlines).dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 9 else { continue }
            guard let pid = Int32(parts[1]) else { continue }
            let nameField = parts[8]
            // NAME is like 127.0.0.1:1234 or *:1234 or [::]:1234
            guard let colonIdx = nameField.lastIndex(of: ":") else { continue }
            let portString = String(nameField[colonIdx...].dropFirst())
                .trimmingCharacters(in: .whitespaces)
            guard let port = Int(portString), port > 0 else { continue }
            map[pid, default: []].append(port)
        }
        return map
    }

    /// Resolve the real app name for a process whose `ps` args were truncated.
    /// Uses NSRunningApplication first (queries the system process registry,
    /// which has the actual display name), then falls back to proc_pidpath().
    private func resolveAppName(pid: Int32) -> String? {
        // 1) NSRunningApplication is the most reliable source for GUI apps.
        //    It returns the actual app name as shown in Activity Monitor,
        //    regardless of how the process was launched or what its binary is named.
        if let app = NSRunningApplication(processIdentifier: pid) {
            if let name = app.localizedName, !name.isEmpty {
                return name
            }
            // Fallback: extract human-readable name from bundle identifier
            // e.g. "com.apple.dt.Xcode" → "Xcode"
            if let bundleID = app.bundleIdentifier {
                let parts = bundleID.split(separator: ".")
                if let last = parts.last {
                    return String(last).localizedCapitalized
                }
            }
        }

        // 2) proc_pidpath fallback — parse the executable path
        let bufferSize = UInt32(PATH_MAX)
        var buffer = [CChar](repeating: 0, count: Int(bufferSize))
        let ret = proc_pidpath(pid, &buffer, bufferSize)
        guard ret > 0 else { return nil }

        let path = String(cString: buffer)
        if let appRange = path.range(of: ".app/") {
            let beforeApp = String(path[..<appRange.lowerBound])
            return (beforeApp as NSString).lastPathComponent
        } else {
            return (path as NSString).lastPathComponent
        }
    }

    /// Extract a human-readable service name from the command line.
    /// Handles the common case where `ps` truncates the executable path at a
    /// space (e.g. ".../Application Support/SwiftMaestro/mcp-servers/..."
    /// → baseName "Application"), by parsing the full command line instead.
    ///
    /// Also detects agent-specific MCP server symlinks:
    ///   `swiftmaestro-mcp-default-assistant` → "default-assistant"
    ///   `swiftmaestro-mcp-apple-platform-coder` → "apple-platform-coder"
    ///
    /// Examples:
    ///   `node .../mcp-servers/firecrawl/dist/index.js` → "firecrawl"
    ///   `node .../mcp-servers/ai-context-bridge/server.js` → "ai-context-bridge"
    ///   `Python .../vision_proxy_server.py ...` → "vision_proxy_server"
    ///   `/.../Application Support/SwiftMaestro/mcp-servers/webclaw/webclaw-mcp` → "webclaw"
    private func resolveProcessName(baseName: String, commandLine: String) -> String {
        // 0) Detect agent-specific MCP server symlinks.
        //    Pattern: swiftmaestro-mcp-<agent-name>
        //    The symlink name is the last path component of the executable.
        //    Skip known non-agent suffixes like "server" (direct binary name).
        let swiftMCPMCPrefix = "swiftmaestro-mcp-"
        let lowerBase = baseName.lowercased()
        if lowerBase.hasPrefix(swiftMCPMCPrefix) {
            let suffix = String(baseName.dropFirst(swiftMCPMCPrefix.count))
            let nonAgentSuffixes: Set<String> = ["server"]
            if !suffix.isEmpty && !nonAgentSuffixes.contains(suffix.lowercased()) {
                return suffix
            }
        }

        // 0b) Rename the bare MCP server binary to a descriptive label.
        if lowerBase == "swiftmaestro-mcp-server" || lowerBase == "swiftmaestro-mcp" {
            return "OpenCode MCP Server"
        }

        // 1) Look for SwiftMaestro MCP server pattern: mcp-servers/<name>/...
        //    This covers firecrawl, ai-context-bridge, xcodebuildmcp, swift-terminals,
        //    read-website-fast, webclaw, etc. — and handles paths containing spaces
        //    like "~/Library/Application Support/SwiftMaestro/mcp-servers/..."
        if let range = commandLine.range(of: "mcp-servers/") {
            let afterPrefix = commandLine[range.upperBound...]
            // Skip .runtime/ node bin if present
            if afterPrefix.hasPrefix(".runtime/") {
                // Pattern: .runtime/node/bin/node .../mcp-servers/<name>/dist/...
                // Look for the SECOND mcp-servers/ occurrence (the script path)
                if let secondRange = commandLine.range(of: "mcp-servers/", range: afterPrefix.startIndex..<afterPrefix.endIndex) {
                    let afterSecond = commandLine[secondRange.upperBound...]
                    let serviceName = String(afterSecond.split(separator: "/").first ?? "mcp")
                    return serviceName
                }
            } else {
                let serviceName = String(afterPrefix.split(separator: "/").first ?? "mcp")
                return serviceName
            }
        }

        // 2) For known generic executables, try to extract the script/service name
        //    from the arguments (e.g. "Python .../vision_proxy_server.py --port")
        let genericNames: Set<String> = ["node", "python", "python3", "application"]
        if genericNames.contains(baseName.lowercased()) {
            let tokens = commandLine.split(separator: " ")
            for token in tokens.dropFirst() { // skip the executable itself
                let path = String(token)
                guard !path.hasPrefix("-") else { continue }
                let fileName = (path as NSString).lastPathComponent
                // Strip extension for display
                if let dotIdx = fileName.lastIndex(of: ".") {
                    return String(fileName[..<dotIdx])
                }
                return fileName
            }
        }

        return baseName
    }
}
