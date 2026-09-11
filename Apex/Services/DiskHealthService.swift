import Foundation

// MARK: - Disk health service
/// Gathers SMART / diskutil health snapshots for mounted volumes.
/// Runs as an actor so diskutil / smartctl processes don't overlap.
actor DiskHealthService {
    static let shared = DiskHealthService()

    init() {}

    enum ScanDepth {
        /// Lightweight snapshot: diskutil info only. Safe for automatic periodic
        /// collection because it does not touch the filesystem or wake sleeping drives.
        case basic
        /// Full snapshot: includes read-only filesystem verify, APFS properties,
        /// Time Machine age, and smartctl. This can be I/O intensive and should only
        /// run when the user explicitly requests it.
        case full
    }

    /// Returns a fresh health snapshot for a single mounted volume, or nil if
    /// diskutil cannot be queried.
    func healthSnapshot(for mountPoint: URL, depth: ScanDepth = .full) async -> DiskHealth? {
        guard let info = await diskutilInfo(at: mountPoint) else { return nil }

        var health = DiskHealth(
            status: statusFromDiskutil(info),
            smartStatus: info.smartStatus,
            busProtocol: info.busProtocol,
            isSSD: info.isSolidState,
            temperatureC: nil,
            powerOnHours: nil,
            wearLevelPercent: nil,
            reallocatedSectorCount: nil,
            pendingSectorCount: nil,
            criticalWarning: nil,
            percentageUsed: nil,
            message: nil,
            capturedAt: Date(),
            freeSpacePercent: nil,
            filesystemVerifyOK: nil,
            filesystemVerifyMessage: nil,
            fileVaultEnabled: nil,
            encryptionEnabled: nil,
            timeMachineLastBackup: nil,
            powerCycleCount: nil,
            startStopCount: nil,
            loadCycleCount: nil,
            udmaCRCErrorCount: nil,
            offlineUncorrectable: nil,
            gSenseErrorRate: nil,
            multiZoneErrorCount: nil
        )

        // Free space percentage.
        if let total = info.totalSize, total > 0, let free = info.freeSpace {
            health.freeSpacePercent = Int((Double(free) / Double(total)) * 100)
        }

        guard depth == .full else {
            if health.message == nil {
                health.message = healthMessage(for: health, info: info)
            }
            return health
        }

        // Filesystem verify (read-only, with a short timeout).
        if let verify = await verifyVolume(at: mountPoint) {
            health.filesystemVerifyOK = verify.ok
            health.filesystemVerifyMessage = verify.message
        }

        // APFS volume properties (FileVault / encryption).
        if let device = info.deviceIdentifier,
           let container = info.apfsContainerReference {
            let props = await apfsVolumeProperties(deviceIdentifier: device, containerReference: container)
            health.fileVaultEnabled = props.fileVault
            health.encryptionEnabled = props.encryption
        }

        // Time Machine backup age (global, cached per refresh pass).
        health.timeMachineLastBackup = await timeMachineLatestBackup()

        // Enhance with smartctl if available (often requires root, so failure
        // is acceptable; we still keep the diskutil baseline).
        if let wholeDisk = info.parentWholeDisk ?? info.deviceIdentifier,
           smartctlPath() != nil {
            let smart = await smartctlHealth(for: wholeDisk)
            merge(smart: smart, into: &health)
        }

        if health.message == nil {
            health.message = healthMessage(for: health, info: info)
        }

        return health
    }

    // MARK: - diskutil

    private struct DiskutilInfo: Sendable {
        var deviceIdentifier: String?
        var parentWholeDisk: String?
        var deviceNode: String?
        var volumeName: String?
        var busProtocol: String?
        var smartStatus: String?
        var isSolidState: Bool?
        var totalSize: Int64?
        var freeSpace: Int64?
        var apfsContainerReference: String?
    }

    private func diskutilInfo(at url: URL) async -> DiskutilInfo? {
        let (_, stdout, _) = await run("/usr/sbin/diskutil", arguments: ["info", "-plist", url.path])
        guard let data = stdout.data(using: .utf8) else { return nil }
        return parseDiskutilPlist(data)
    }

    private func parseDiskutilPlist(_ data: Data) -> DiskutilInfo? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.ReadOptions(), format: nil) as? [String: Any]
        else { return nil }

        return DiskutilInfo(
            deviceIdentifier: plist["DeviceIdentifier"] as? String,
            parentWholeDisk: plist["ParentWholeDisk"] as? String,
            deviceNode: plist["DeviceNode"] as? String,
            volumeName: plist["VolumeName"] as? String,
            busProtocol: plist["BusProtocol"] as? String,
            smartStatus: plist["SMARTStatus"] as? String,
            isSolidState: plist["SolidState"] as? Bool,
            totalSize: (plist["TotalSize"] as? NSNumber)?.int64Value,
            freeSpace: (plist["FreeSpace"] as? NSNumber)?.int64Value,
            apfsContainerReference: plist["APFSContainerReference"] as? String
        )
    }

    private func statusFromDiskutil(_ info: DiskutilInfo) -> DiskHealth.Status {
        if let smart = info.smartStatus {
            switch smart.lowercased() {
            case "verified": return .healthy
            case "failing": return .failing
            default: return .unsupported
            }
        }
        return .unknown
    }

    private func healthMessage(for health: DiskHealth, info: DiskutilInfo) -> String {
        if health.filesystemVerifyOK == false {
            return health.filesystemVerifyMessage ?? "Filesystem verification failed."
        }
        switch health.status {
        case .healthy:
            return "SMART status is verified."
        case .failing:
            return "SMART reported failing. Back up and replace this drive."
        case .unsupported:
            return "SMART is not supported or not available for this device."
        case .caution:
            return "Health indicators suggest caution."
        case .unknown:
            return info.smartStatus == nil
                ? "No SMART data available from diskutil."
                : "Health status could not be determined."
        }
    }

    // MARK: - Filesystem / volume checks

    private func verifyVolume(at url: URL) async -> (ok: Bool, message: String)? {
        let (code, stdout, _) = await run(
            "/usr/sbin/diskutil",
            arguments: ["verifyVolume", url.path],
            timeoutSeconds: 15
        )
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = code == 0 && trimmed.localizedStandardContains("appears to be OK")
        let message = ok
            ? "Filesystem verified"
            : (trimmed.components(separatedBy: "\n").last?.trimmingCharacters(in: .whitespaces) ?? "Verify failed")
        return (ok, message)
    }

    private func apfsVolumeProperties(
        deviceIdentifier: String,
        containerReference: String
    ) async -> (fileVault: Bool?, encryption: Bool?) {
        let (_, stdout, _) = await run(
            "/usr/sbin/diskutil",
            arguments: ["apfs", "list", "-plist", containerReference]
        )
        guard let data = stdout.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, options: PropertyListSerialization.ReadOptions(), format: nil
              ) as? [String: Any],
              let containers = plist["Containers"] as? [[String: Any]] else {
            return (nil, nil)
        }
        for container in containers {
            guard let volumes = container["Volumes"] as? [[String: Any]] else { continue }
            for volume in volumes {
                guard let dev = volume["DeviceIdentifier"] as? String,
                      dev == deviceIdentifier else { continue }
                return (
                    volume["FileVault"] as? Bool,
                    volume["Encryption"] as? Bool
                )
            }
        }
        return (nil, nil)
    }

    // MARK: - Time Machine

    private var cachedTimeMachineBackup: Date?
    private var cachedTimeMachineFetchAt: Date?

    private func timeMachineLatestBackup() async -> Date? {
        if let cached = cachedTimeMachineBackup,
           let fetchedAt = cachedTimeMachineFetchAt,
           Date().timeIntervalSince(fetchedAt) < 60 {
            return cached
        }
        let (_, stdout, _) = await run("/usr/bin/tmutil", arguments: ["latestbackup"])
        let path = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? ""
        guard !path.isEmpty else {
            cachedTimeMachineBackup = nil
            cachedTimeMachineFetchAt = Date()
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.timeZone = TimeZone.current
        let last = (path as NSString).lastPathComponent
        let date = formatter.date(from: last)
        cachedTimeMachineBackup = date
        cachedTimeMachineFetchAt = Date()
        return date
    }

    // MARK: - smartctl

    private func smartctlPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/smartctl",
            "/usr/local/bin/smartctl",
            "/usr/sbin/smartctl",
            "/usr/bin/smartctl"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func smartctlHealth(for device: String) async -> DiskHealth? {
        let node = device.hasPrefix("/dev/") ? device : "/dev/\(device)"
        let path = smartctlPath() ?? "smartctl"
        // Cap smartctl at 25s so a sleeping/bad USB drive can't hang the
        // health actor indefinitely and stall subsequent volume checks.
        let (_, stdout, _) = await run(path, arguments: ["-a", node], timeoutSeconds: 25)

        var health = DiskHealth(
            status: .unknown,
            smartStatus: nil,
            busProtocol: nil,
            isSSD: nil,
            temperatureC: nil,
            powerOnHours: nil,
            wearLevelPercent: nil,
            reallocatedSectorCount: nil,
            pendingSectorCount: nil,
            criticalWarning: nil,
            percentageUsed: nil,
            message: nil,
            capturedAt: Date(),
            freeSpacePercent: nil,
            filesystemVerifyOK: nil,
            filesystemVerifyMessage: nil,
            fileVaultEnabled: nil,
            encryptionEnabled: nil,
            timeMachineLastBackup: nil,
            powerCycleCount: nil,
            startStopCount: nil,
            loadCycleCount: nil,
            udmaCRCErrorCount: nil,
            offlineUncorrectable: nil,
            gSenseErrorRate: nil,
            multiZoneErrorCount: nil
        )

        let lines = stdout.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            let text = String(line)

            if text.contains("SMART overall-health self-assessment test result: PASSED") {
                health.status = .healthy
            } else if text.contains("SMART overall-health self-assessment test result: FAILED") {
                health.status = .failing
            }

            // NVMe critical warning
            if text.lowercased().hasPrefix("critical warning:") {
                let value = text.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if value != "0x00" && !value.isEmpty && value != "0" {
                    health.criticalWarning = value
                    health.status = .failing
                }
            }

            // NVMe percentage used
            if text.lowercased().hasPrefix("percentage used:") {
                health.percentageUsed = intValue(from: text)
            }

            // NVMe / SCSI temperature
            if text.lowercased().hasPrefix("temperature:") {
                health.temperatureC = intValue(from: text)
            }

            // NVMe power on hours
            if text.lowercased().hasPrefix("power on hours:") {
                health.powerOnHours = intValue(from: text)
            }

            // ATA attributes
            if text.contains("Reallocated_Sector_Ct") {
                health.reallocatedSectorCount = ataRawValue(from: text)
            }
            if text.contains("Current_Pending_Sector") {
                health.pendingSectorCount = ataRawValue(from: text)
            }
            if text.contains("Power_On_Hours") {
                health.powerOnHours = ataRawValue(from: text)
            }
            if text.contains("Temperature_Celsius") {
                health.temperatureC = ataRawValue(from: text)
            }
            if text.contains("Wear_Leveling_Count") || text.contains("Media_Wearout_Indicator") {
                if let raw = ataRawValue(from: text), raw > 0, raw <= 100 {
                    health.wearLevelPercent = raw
                }
            }
            if text.contains("Power_Cycle_Count") {
                health.powerCycleCount = ataRawValue(from: text)
            }
            if text.contains("Start_Stop_Count") {
                health.startStopCount = ataRawValue(from: text)
            }
            if text.contains("Load_Cycle_Count") {
                health.loadCycleCount = ataRawValue(from: text)
            }
            if text.contains("UDMA_CRC_Error_Count") {
                health.udmaCRCErrorCount = ataRawValue(from: text)
            }
            if text.contains("Offline_Uncorrectable") {
                health.offlineUncorrectable = ataRawValue(from: text)
            }
            if text.contains("G-Sense_Error_Rate") {
                health.gSenseErrorRate = ataRawValue(from: text)
            }
            if text.contains("Multi_Zone_Error_Rate") {
                health.multiZoneErrorCount = ataRawValue(from: text)
            }
        }

        if health.status == .failing || health.criticalWarning != nil {
            health.message = "SMART reports failing health. Back up and replace this drive."
        } else if health.status == .healthy {
            health.message = "SMART self-test passed."
        }

        return health
    }

    private func merge(smart: DiskHealth?, into health: inout DiskHealth) {
        guard let smart else { return }
        if smart.status != .unknown { health.status = smart.status }
        if let v = smart.temperatureC { health.temperatureC = v }
        if let v = smart.powerOnHours { health.powerOnHours = v }
        if let v = smart.wearLevelPercent { health.wearLevelPercent = v }
        if let v = smart.reallocatedSectorCount { health.reallocatedSectorCount = v }
        if let v = smart.pendingSectorCount { health.pendingSectorCount = v }
        if let v = smart.criticalWarning { health.criticalWarning = v }
        if let v = smart.percentageUsed { health.percentageUsed = v }
        if let v = smart.powerCycleCount { health.powerCycleCount = v }
        if let v = smart.startStopCount { health.startStopCount = v }
        if let v = smart.loadCycleCount { health.loadCycleCount = v }
        if let v = smart.udmaCRCErrorCount { health.udmaCRCErrorCount = v }
        if let v = smart.offlineUncorrectable { health.offlineUncorrectable = v }
        if let v = smart.gSenseErrorRate { health.gSenseErrorRate = v }
        if let v = smart.multiZoneErrorCount { health.multiZoneErrorCount = v }
        if let m = smart.message { health.message = m }
    }

    // MARK: - Parsing helpers

    private func intValue(from line: String) -> Int? {
        let digits = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }

    private func ataRawValue(from line: String) -> Int? {
        // ATA attribute lines are space/column delimited; the raw value is the
        // last integer token (e.g. "200 200 140 ... 0").
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
        for token in tokens.reversed() {
            let s = String(token)
            if let value = Int(s) { return value }
            // Some raw values are comma-separated: "1234 (1234 0 ...)"
            if let first = s.components(separatedBy: CharacterSet(charactersIn: "(, )").union(.whitespaces)).first,
               let value = Int(first) {
                return value
            }
        }
        return nil
    }

    // MARK: - Process helper

    private func run(
        _ executable: String,
        arguments: [String],
        timeoutSeconds: TimeInterval? = nil
    ) async -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (
                    process.terminationStatus,
                    String(data: outData, encoding: .utf8) ?? "",
                    String(data: errData, encoding: .utf8) ?? ""
                ))
            }

            do {
                try process.run()
                if let timeout = timeoutSeconds {
                    Task {
                        try? await Task.sleep(for: .seconds(timeout))
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                }
            } catch {
                continuation.resume(returning: (-1, "", String(describing: error)))
            }
        }
    }
}
