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
        "vision_proxy_server", "modelmanagerd"
    ]

    /// Xcode-launched apps get truncated args like "-NSDocumentRevisionsDebugMode YES".
    /// This flag is passed by Xcode to every debug-launched app.
    private static let xcodeLaunchMarker = "-NSDocumentRevisionsDebugMode"

    // MARK: - Public

    func collect() async -> [AIModelSnapshot] {
        var snapshots = [AIModelSnapshot]()
        var nameCounts: [String: Int] = [:]

        for process in processList() {
            let lowerName = process.name.lowercased()

            // Match if the process name contains any watched name,
            // OR if it looks like a model-server (ports in args, --model flag, etc.)
            let isWatched = Self.watchedProcessNames.contains { lowerName.contains($0) }

            // Match AI model servers by command line content.
            // NOTE: macOS truncates `ps -args` to ~80 chars, so we can't rely on
            // seeing the full path. Match on what IS visible.
            let cl = process.commandLine ?? ""
            let looksLikeModelServer = cl.contains("--model")
                || cl.contains("mlx")
                || cl.contains(".gguf")
                || cl.contains("omlx")
                || cl.contains("vision_proxy")
                || cl.contains("deltafin")
                || cl.contains("SwiftMaestro")

            // Xcode-launched apps get truncated to just the launch flags.
            // Detect them by the Xcode debug flag and flag as "needs name resolution".
            let isXcodeLaunch = cl.hasPrefix("-NSDocument")
                || cl.hasPrefix("-NS")
                || cl == Self.xcodeLaunchMarker

            guard isWatched || looksLikeModelServer || isXcodeLaunch else { continue }

            // Resolve a human-readable name for the process.
            // For Xcode-launched processes, always try NSRunningApplication first
            // (ps args are truncated and don't contain the executable path).
            // For generic executables (node, Python), extract the actual service
            // name from the command line instead of showing "node" or "Python".
            let displayName: String
            if isXcodeLaunch {
                // Xcode-launched processes have truncated args like
                // "-NSDocumentRevisionsDebugMode YES" — the real name must
                // come from NSRunningApplication or proc_pidpath.
                displayName = resolveAppName(pid: process.pid) ?? resolveProcessName(
                    baseName: process.name,
                    commandLine: process.commandLine ?? ""
                )
            } else {
                displayName = resolveProcessName(
                    baseName: process.name,
                    commandLine: process.commandLine ?? ""
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

            let status: AIModelSnapshot.ProcessStatus
            switch process.state {
            case "R":  status = .running
            case "S":  status = .sleeping
            case "T":  status = .stopped
            case "Z":  status = .zombie
            default:   status = .idle
            }

            snapshots.append(AIModelSnapshot(
                id: process.pid,
                name: finalName,
                cpuPercent: process.cpuPercent,
                memoryBytes: process.residentMemoryBytes,
                threads: 0,  // Not available from ps on macOS
                status: status
            ))
        }

        return snapshots.sorted { $0.name < $1.name }
    }

    // MARK: - Process Scanning

    private struct ProcessInfo {
        let pid: Int32
        let name: String
        let state: String       // R, S, T, Z, etc.
        let cpuPercent: Double
        let residentMemoryBytes: UInt64
        let commandLine: String?
    }

    /// Uses `ps` to get all processes with CPU%, memory, state, and command line.
    /// NOTE: We intentionally skip the `comm` column because macOS truncates it
    /// to 15 characters (e.g. "SwiftMaestro" → "SwiftMaest"), making name
    /// matching impossible. Instead we parse the executable basename from `args`.
    private func processList() -> [ProcessInfo] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        // -args gives the full command line without truncation
        task.arguments = ["-eo", "pid,stat,%cpu,rss,args"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return []
        }

        // IMPORTANT: Read pipe data BEFORE waitUntilExit() to avoid deadlock.
        // ps output on this system is ~144KB, but macOS pipe buffers are only 64KB.
        // If we wait for the process to exit first, it blocks on write when the
        // buffer fills, and we block waiting for it to exit — classic deadlock.
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

            // Parse: PID STAT %CPU RSS ARGS...
            // ps uses fixed-width columns with multiple spaces between fields.
            // .components(separatedBy: .whitespaces) preserves empty strings for
            // consecutive spaces, so we filter them out to get clean field access.
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 5 else { continue }

            guard let pid = Int32(parts[0]) else { continue }
            let state = parts[1]
            let cpuPercent = Double(parts[2]) ?? 0
            let rssKB = UInt64(parts[3]) ?? 0

            // Reconstruct args string (everything after RSS) using the same
            // field-walking approach on the original trimmed string, which correctly
            // handles variable-width whitespace between fixed-width columns.
            var fieldEnd = trimmed.startIndex
            var fieldCount = 0
            while fieldEnd < trimmed.endIndex && fieldCount < 4 {
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
            // First token is the executable path (may have spaces if quoted, but
            // rare for AI processes). Take the last path component.
            let execName: String
            if let spaceIdx = commandLine.firstIndex(of: " ") {
                execName = String(commandLine[commandLine.startIndex..<spaceIdx])
            } else {
                execName = commandLine
            }
            let baseName = (execName as NSString).lastPathComponent

            results.append(ProcessInfo(
                pid: pid,
                name: baseName,
                state: state,
                cpuPercent: cpuPercent,
                residentMemoryBytes: rssKB * 1024,
                commandLine: commandLine
            ))
        }

        return results
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
