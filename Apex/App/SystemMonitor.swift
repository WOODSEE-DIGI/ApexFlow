import Foundation
import Observation

@Observable
@MainActor
final class SystemMonitor {
    let cpu        = CPUData()
    let memory     = MemoryData()
    let disk       = DiskData()
    let network    = NetworkData()
    let processes  = ProcessData()
    let conn       = ConnData()
    let aiModel    = AIModelData()  // AI model monitoring

    private let cpuCollector      = CPUCollector()
    private let memCollector      = MemoryCollector()
    private let diskCollector     = DiskCollector()
    private let diskHealthService = DiskHealthService()
    private let netCollector      = NetworkCollector()
    private let procCollector     = ProcessCollector()
    private let connCollector     = ConnCollector()
    private let midiCollector     = MIDICollector()
    private let oscCollector      = OSCCollector()
    private let aiModelCollector  = AIModelCollector()  // AI process collector

    private var tasks: [Task<Void, Never>] = []

    func start() {
        guard tasks.isEmpty else { return }

        // Start OSC listener and MIDI setup
        oscCollector.start(on: 8000)
        Task { await midiCollector.setup() }

        // CPU — 200ms
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let snap = await self.cpuCollector.collect()
                self.cpu.update(from: snap)
                try? await Task.sleep(for: .milliseconds(200))
            }
        })

        // Memory — 1s
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let snap = await self.memCollector.collect()
                self.memory.update(from: snap)
                try? await Task.sleep(for: .seconds(1))
            }
        })

        // Disks — 1s + TB activity correlation
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let snaps = await self.diskCollector.collect()
                self.disk.update(from: snaps)
                // Push external disk I/O into Thunderbolt port activity histories
                self.correlateTBActivity()
                try? await Task.sleep(for: .seconds(1))
            }
        })

        // Disk health (S.M.A.R.T.) — 60s, lightweight only.
        // Full verifyVolume + smartctl scans are I/O intensive and can freeze the
        // system, so automatic collection uses basic diskutil info only. The user
        // can trigger a full scan manually from the Storage Health panel.
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                await self.refreshDiskHealth(depth: .basic)
                try? await Task.sleep(for: .seconds(60))
            }
        })

        // Network — 500ms
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let snap = await self.netCollector.collect()
                self.network.update(from: snap)
                try? await Task.sleep(for: .milliseconds(500))
            }
        })

        // Processes — 2s
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let snaps = await self.procCollector.collect()
                let flagged = self.flagAIFamily(in: snaps)
                self.processes.update(from: flagged.snapshots, aiPIDs: flagged.aiPIDs, aiRoles: flagged.aiRoles)
                try? await Task.sleep(for: .seconds(2))
            }
        })

        // Connectivity (TB/USB/WiFi/BT) — 5s
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let snap = await self.connCollector.collect()
                self.conn.update(from: snap)
                try? await Task.sleep(for: .seconds(5))
            }
        })

        // MIDI — 200ms (needs to be fast for live message display)
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let infos = await self.midiCollector.collect()
                self.conn.updateMIDI(from: infos)
                try? await Task.sleep(for: .milliseconds(200))
            }
        })

        // OSC — drain buffer at 100ms
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let messages = self.oscCollector.drain()
                for msg in messages {
                    self.conn.addOSCMessage(msg)
                }
                let listening = self.oscCollector.isListening
                self.conn.setOSCListening(listening)
                try? await Task.sleep(for: .milliseconds(100))
            }
        })

        // AI Model Processes — 2s (monitor for hangs and token activity)
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                let snaps = await self.aiModelCollector.collect()
                self.aiModel.updateProcesses(from: snaps)
                try? await Task.sleep(for: .seconds(2))
            }
        })

        // AI Token Activity Monitor — check for idle/timeout every 1s
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                // Update idle/timeout status based on token activity
                self.aiModel.updateActivityStatus()
                try? await Task.sleep(for: .seconds(1))
            }
        })

        // Silent Period Detector — alert if model is silent for > 10 seconds (no tokens but still "active")
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { continue }
                self.checkSilentPeriods()
                try? await Task.sleep(for: .seconds(3))
            }
        })

        // MARK: - SwiftMaestro Distributed Notifications
        // Observe AI activity broadcasts from SwiftMaestro via NSDistributedNotificationCenter.
        // These notifications carry token rates, request lifecycle, and tool call events
        // so ApexFlow's AI monitor panel updates in real-time.
        startObservingSwiftMaestroNotifications()
    }

    // MARK: - SwiftMaestro Notification Observation

    private var notificationObservers: [NSObjectProtocol] = []

    private func startObservingSwiftMaestroNotifications() {
        let center = DistributedNotificationCenter.default()

        // Generation started
        let startedObs = center.addObserver(
            forName: Notification.Name("com.woodseedigi.swiftmaestro.generationStarted"),
            object: nil, queue: .main
        ) { [weak self] note in
            if let appName = note.userInfo?["appName"] as? String {
                self?.aiModel.broadcastingAppName = appName
            }
            self?.aiModel.startModelRequest()
        }
        notificationObservers.append(startedObs)

        // Generation completed
        let completedObs = center.addObserver(
            forName: Notification.Name("com.woodseedigi.swiftmaestro.generationCompleted"),
            object: nil, queue: .main
        ) { [weak self] note in
            if let appName = note.userInfo?["appName"] as? String {
                self?.aiModel.broadcastingAppName = appName
            }
            self?.aiModel.completeModelRequest()
        }
        notificationObservers.append(completedObs)

        // Generation failed
        let failedObs = center.addObserver(
            forName: Notification.Name("com.woodseedigi.swiftmaestro.generationFailed"),
            object: nil, queue: .main
        ) { [weak self] note in
            if let appName = note.userInfo?["appName"] as? String {
                self?.aiModel.broadcastingAppName = appName
            }
            self?.aiModel.completeModelRequest()
        }
        notificationObservers.append(failedObs)

        // Generation cancelled
        let cancelledObs = center.addObserver(
            forName: Notification.Name("com.woodseedigi.swiftmaestro.generationCancelled"),
            object: nil, queue: .main
        ) { [weak self] note in
            if let appName = note.userInfo?["appName"] as? String {
                self?.aiModel.broadcastingAppName = appName
            }
            self?.aiModel.completeModelRequest()
        }
        notificationObservers.append(cancelledObs)

        // Token rate updates (throttled to 1/sec by SwiftMaestro)
        let tokenObs = center.addObserver(
            forName: Notification.Name("com.woodseedigi.swiftmaestro.tokenRateUpdate"),
            object: nil, queue: .main
        ) { [weak self] note in
            guard let userInfo = note.userInfo else { return }
            if let appName = userInfo["appName"] as? String {
                self?.aiModel.broadcastingAppName = appName
            }
            if let tps = userInfo["tokensPerSecond"] as? Double {
                self?.aiModel.tokenActivity.tokensPerSecond = tps
            }
            if let total = userInfo["totalTokens"] as? Int {
                self?.aiModel.tokenActivity.totalTokens = total
            }
            // Record individual tokens for the activity tracker
            self?.aiModel.recordToken()
        }
        notificationObservers.append(tokenObs)

        // Tool started
        let toolStartedObs = center.addObserver(
            forName: Notification.Name("com.woodseedigi.swiftmaestro.toolStarted"),
            object: nil, queue: .main
        ) { [weak self] note in
            guard let userInfo = note.userInfo,
                  let name = userInfo["toolName"] as? String,
                  let id = userInfo["toolID"] as? String else { return }
            _ = self?.aiModel.addToolCall(name: name, toolID: id)
        }
        notificationObservers.append(toolStartedObs)

        // Tool completed
        let toolCompletedObs = center.addObserver(
            forName: Notification.Name("com.woodseedigi.swiftmaestro.toolCompleted"),
            object: nil, queue: .main
        ) { [weak self] note in
            guard let userInfo = note.userInfo,
                  let id = userInfo["toolID"] as? String else { return }
            let duration = userInfo["duration"] as? TimeInterval ?? 0
            self?.aiModel.completeToolCall(id: id, duration: duration)
        }
        notificationObservers.append(toolCompletedObs)

        NSLog("[ApexFlow] Observing SwiftMaestro AI activity notifications")
    }

    private func stopObservingSwiftMaestroNotifications() {
        let center = DistributedNotificationCenter.default()
        for obs in notificationObservers {
            center.removeObserver(obs)
        }
        notificationObservers.removeAll()
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        oscCollector.stop()
        stopObservingSwiftMaestroNotifications()
    }

    // MARK: - TB/USB/Disk correlation
    /// Attribute disk I/O to the Thunderbolt port or USB device it is connected to.
    /// Internal disk I/O is ignored here because it is not relevant to the
    /// connectivity panels.
    private func correlateTBActivity() {
        var tbRead:  [UInt64: Double] = [:]
        var tbWrite: [UInt64: Double] = [:]
        var usbRead:  [UInt64: Double] = [:]
        var usbWrite: [UInt64: Double] = [:]

        for d in disk.disks where d.mountpoint != "/" {
            switch d.transport {
            case .thunderbolt(let controllerID):
                tbRead[controllerID, default: 0]  += d.readRate
                tbWrite[controllerID, default: 0] += d.writeRate
            case .usb(let registryID):
                usbRead[registryID, default: 0]  += d.readRate
                usbWrite[registryID, default: 0] += d.writeRate
            default:
                break
            }
        }

        conn.updateTBActivity(perPort: tbRead, writeRates: tbWrite)
        conn.updateUSBActivity(perDevice: usbRead, writeRates: usbWrite)
    }

    // MARK: - Disk health refresh
    /// Query diskutil for every mounted disk and update the in-memory health snapshot.
    /// Use `.basic` for automatic periodic collection and `.full` only when the user
    /// explicitly requests a deep scan, because verifyVolume + smartctl can be I/O
    /// intensive enough to freeze the whole machine.
    private func refreshDiskHealth(depth: DiskHealthService.ScanDepth) async {
        let currentDisks = disk.disks
        for diskInfo in currentDisks {
            let url = URL(fileURLWithPath: diskInfo.mountpoint)
            if let health = await diskHealthService.healthSnapshot(for: url, depth: depth) {
                disk.update(health: health, for: diskInfo.id)
            }
        }
    }

    // MARK: - AI Process Family Highlighting

    /// Walks the process tree to mark every AI model process, MCP server,
    /// and any descendant daemon/child spawned by them. The main process
    /// list can then highlight AI-related rows.
    private func flagAIFamily(in snapshots: [ProcessSnapshot]) -> (snapshots: [ProcessSnapshot], aiPIDs: Set<Int32>, aiRoles: [Int32: String]) {
        let aiProcesses = aiModel.aiProcesses
        var aiPIDs = Set(aiProcesses.map(\.id))

        // Propagate AI ancestry through the process tree (direct children only,
        // repeated until stable, to catch grandchildren).
        let pidToPPID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0.ppid) })
        var changed = true
        while changed {
            let before = aiPIDs.count
            for (pid, ppid) in pidToPPID where !aiPIDs.contains(pid) && aiPIDs.contains(ppid) {
                aiPIDs.insert(pid)
            }
            changed = aiPIDs.count > before
        }

        // Build role labels from the AI collector, and label descendants as daemons.
        var aiRoles: [Int32: String] = [:]
        for proc in aiProcesses {
            aiRoles[proc.id] = proc.kind.label
        }
        for pid in aiPIDs where aiRoles[pid] == nil {
            aiRoles[pid] = "AI daemon"
        }

        let flagged = snapshots.map { snap in
            ProcessSnapshot(
                id: snap.id,
                ppid: snap.ppid,
                name: snap.name,
                user: snap.user,
                cpuPercent: snap.cpuPercent,
                memoryBytes: snap.memoryBytes,
                threads: snap.threads,
                status: snap.status,
                isAI: aiPIDs.contains(snap.id),
                aiRole: aiRoles[snap.id]
            )
        }

        return (flagged, aiPIDs, aiRoles)
    }

    // MARK: - AI Model Helper Methods

    /// Record that a token was received (call this when streaming tokens from AI)
    func recordAIToken() {
        aiModel.recordToken()
    }

    /// Call when sending a request to the AI model (e.g., user message sent)
    func startModelRequest() {
        aiModel.startModelRequest()
    }

    /// Call when receiving first token from model
    func receivedFirstToken() {
        aiModel.receivedFirstToken()
    }

    /// Call when model response is complete
    func completeModelRequest() {
        aiModel.completeModelRequest()
    }

    /// Track an MCP tool call starting (returns tool ID for tracking)
    func startToolCall(name: String, input: String? = nil) -> String {
        return aiModel.addToolCall(name: name, input: input)
    }

    /// Mark an MCP tool call as completed
    func completeToolCall(id: String, duration: TimeInterval, output: String? = nil) {
        aiModel.completeToolCall(id: id, duration: duration, output: output)
    }

    /// Mark an MCP tool call as failed
    func failToolCall(id: String, error: String) {
        aiModel.failToolCall(id: id, error: error)
    }

    /// Cancel a tool call
    func cancelToolCall(id: String) {
        aiModel.cancelToolCall(id: id)
    }

    /// Check if AI model is currently active
    var isAIActive: Bool {
        aiModel.isActive
    }

    /// Check if AI model has soft timeout (warning)
    var hasSoftAITimeout: Bool {
        aiModel.hasSoftTimeout
    }

    /// Check if AI model has hard timeout (error)
    var hasHardAITimeout: Bool {
        aiModel.hasHardTimeout
    }

    /// Check if model is in silent processing period
    var isSilentProcessing: Bool {
        aiModel.isSilentProcessing
    }

    /// Get silent duration (seconds since last token)
    var silentDuration: TimeInterval {
        aiModel.currentResponse.silentDuration
    }

    /// Get active tool calls
    var activeToolCalls: [MCPToolCall] {
        aiModel.activeToolCalls
    }

    /// Get pending tool count
    var pendingToolCount: Int {
        aiModel.pendingToolCount
    }

    // MARK: - Silent Period Detection
    
    /// Check for silent periods and log warnings
    private func checkSilentPeriods() {
        let silentTime = aiModel.currentResponse.silentDuration
        
        if silentTime >= 10.0 && silentTime < 30.0 {
            // Warning: Model silent for > 10 seconds
            print("[Apex Flow] ⚠️ AI model silent for \(Int(silentTime))s")
        } else if silentTime >= 30.0 && silentTime < 60.0 {
            // Warning: Model silent for > 30 seconds
            print("[Apex Flow] ⚠️⚠️ AI model silent for \(Int(silentTime))s - SOFT TIMEOUT")
        } else if silentTime >= 60.0 {
            // Error: Model silent for > 60 seconds
            print("[Apex Flow] 🚨 AI model silent for \(Int(silentTime))s - HARD TIMEOUT")
        }
    }
}
