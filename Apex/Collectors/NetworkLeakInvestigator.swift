import Foundation
import Darwin

// MARK: - Network Leak Investigator

/// Gathers file-based evidence about a process so the user can decide why it
/// is making a network connection when simple heuristics don't explain it.
actor NetworkLeakInvestigator {

    func investigate(alert: WANConnectionAlert) async -> InvestigationReport {
        let pid = alert.pid
        let executablePath = Self.executablePath(forPID: pid)
        let commandLine = Self.commandLine(forPID: pid)

        var configFindings: [ConfigFinding] = []

        // Syncthing: read config.xml to show devices/folders.
        if alert.processName.lowercased() == "syncthing" {
            if let finding = await syncthingFinding(commandLine: commandLine) {
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

    // MARK: - Syncthing config

    private func syncthingFinding(commandLine: String?) async -> ConfigFinding? {
        let configURL: URL

        if let customHome = Self.extractHome(from: commandLine) {
            configURL = customHome.appendingPathComponent("config.xml")
        } else {
            // Default macOS Syncthing config locations
            let defaults = [
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/Syncthing/config.xml"),
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".config/syncthing/config.xml")
            ]
            guard let found = defaults.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
                return ConfigFinding(
                    source: "Syncthing config",
                    detail: "No Syncthing config.xml found in the default locations."
                )
            }
            configURL = found
        }

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return ConfigFinding(
                source: "Syncthing config",
                detail: "Expected config at \(configURL.path) but it does not exist."
            )
        }

        do {
            let xml = try XMLDocument(contentsOf: configURL)
            let deviceCount = try? xml.nodes(forXPath: "//device").count
            let folderCount = try? xml.nodes(forXPath: "//folder").count
            let deviceNames = (try? xml.nodes(forXPath: "//device/@name").compactMap { $0.stringValue }) ?? []

            var detail = "Config found at \(configURL.path)."
            if let devices = deviceCount {
                detail += " It defines \(devices) device(s)"
                if !deviceNames.isEmpty {
                    detail += ": \(deviceNames.joined(separator: ", "))."
                } else {
                    detail += "."
                }
            }
            if let folders = folderCount {
                detail += " There are \(folders) shared folder(s)."
            }
            detail += " A connection on port 22000 is usually direct sync with one of these devices."
            return ConfigFinding(source: "Syncthing config", detail: detail)
        } catch {
            return ConfigFinding(
                source: "Syncthing config",
                detail: "Found config at \(configURL.path) but could not parse it: \(error.localizedDescription)"
            )
        }
    }

    private static func extractHome(from commandLine: String?) -> URL? {
        guard let cl = commandLine else { return nil }
        // Syncthing supports -home=<path> and -home <path>
        if let range = cl.range(of: "-home=") {
            let after = cl[range.upperBound...]
            let token = String(after.split(separator: " ").first ?? "")
            return URL(fileURLWithPath: (token as NSString).expandingTildeInPath)
        }
        if let range = cl.range(of: "-home ") {
            let after = cl[range.upperBound...]
            let token = String(after.split(separator: " ").first ?? "")
            return URL(fileURLWithPath: (token as NSString).expandingTildeInPath)
        }
        return nil
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
