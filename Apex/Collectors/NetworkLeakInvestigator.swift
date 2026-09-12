import Foundation
import Darwin

// MARK: - Network Leak Investigator

/// Gathers file-based evidence about a process so the user can decide why it
/// is making a network connection when simple heuristics don't explain it.
actor NetworkLeakInvestigator {

    private let profiles: [any InvestigationProfile]

    init(profiles: [any InvestigationProfile] = InvestigationProfiles.default) {
        self.profiles = profiles
    }

    func investigate(alert: WANConnectionAlert) async -> InvestigationReport {
        let pid = alert.pid
        let executablePath = Self.executablePath(forPID: pid)
        let commandLine = Self.commandLine(forPID: pid)

        var configFindings: [ConfigFinding] = []

        // Run every matching profile to collect evidence.
        for profile in profiles where profile.matches(alert: alert, executablePath: executablePath) {
            if let finding = await profile.finding(for: alert, commandLine: commandLine, executablePath: executablePath) {
                configFindings.append(finding)
            }
        }

        // Bundle info for GUI apps.
        var bundleID: String?
        var bundleName: String?
        if let path = executablePath,
           let appPath = Self.containingAppBundle(path: path) {
            let info = Self.bundleInfo(at: appPath)
            bundleID = info["CFBundleIdentifier"]
            bundleName = info["CFBundleName"] ?? info["CFBundleDisplayName"]
        }

        let summary = Self.summary(
            alert: alert,
            executablePath: executablePath,
            bundleName: bundleName,
            bundleID: bundleID,
            configFindings: configFindings
        )

        return InvestigationReport(
            id: alert.id,
            alertID: alert.id,
            executablePath: executablePath,
            bundleIdentifier: bundleID,
            bundleName: bundleName,
            commandLine: commandLine,
            configFindings: configFindings,
            summary: summary
        )
    }

    // MARK: - Process metadata

    private static func executablePath(forPID pid: Int32) -> String? {
        let size = Int(PATH_MAX)
        var buffer = [CChar](repeating: 0, count: size)
        guard proc_pidpath(pid, &buffer, UInt32(size)) > 0 else { return nil }
        let bytes = buffer.map(UInt8.init)
        let terminator = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[..<terminator], as: UTF8.self)
    }

    private static func commandLine(forPID pid: Int32) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", String(pid), "-o", "args="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else { return nil }
        return output
    }

    // MARK: - Bundle metadata

    private static func containingAppBundle(path: String) -> String? {
        var current = path as NSString
        while current.length > 1 {
            if current.pathExtension == "app" {
                return current as String
            }
            let parent = current.deletingLastPathComponent
            if parent == current as String { break }
            current = parent as NSString
        }
        return nil
    }

    private static func bundleInfo(at appPath: String) -> [String: String] {
        let plistURL = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }

        var info: [String: String] = [:]
        if let id = plist["CFBundleIdentifier"] as? String { info["CFBundleIdentifier"] = id }
        if let name = plist["CFBundleDisplayName"] as? String { info["CFBundleDisplayName"] = name }
        else if let name = plist["CFBundleName"] as? String { info["CFBundleName"] = name }
        return info
    }

    // MARK: - Summary

    private static func summary(
        alert: WANConnectionAlert,
        executablePath: String?,
        bundleName: String?,
        bundleID: String?,
        configFindings: [ConfigFinding]
    ) -> String {
        var parts: [String] = []

        if let name = bundleName ?? bundleID {
            parts.append("Process belongs to \(name).")
        }

        if let path = executablePath {
            parts.append("Executable: \(path).")
        }

        if !configFindings.isEmpty {
            parts.append(contentsOf: configFindings.map(\.detail))
        } else {
            parts.append("No application-specific configuration files were found to explain this connection.")
        }

        parts.append("The remote endpoint is \(alert.displayEndpoint).")
        return parts.joined(separator: " ")
    }
}

// MARK: - Profile matching helpers

extension InvestigationProfile {
    func matches(alert: WANConnectionAlert, executablePath: String?) -> Bool {
        let procLower = alert.processName.lowercased()
        if processNames.contains(where: { procLower.contains($0.lowercased()) || $0.lowercased().contains(procLower) }) {
            return true
        }
        if let bid = alert.bundleID?.lowercased(),
           bundleIDs.contains(where: { bid == $0.lowercased() || bid.hasPrefix($0.lowercased() + ".") }) {
            return true
        }
        if let path = executablePath?.lowercased() {
            for name in processNames {
                if path.contains(name.lowercased()) { return true }
            }
        }
        return false
    }
}
