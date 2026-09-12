import Foundation
import Darwin

// MARK: - Investigation Profile Protocol

/// A profile that knows how to explain a network connection for a specific app
/// by reading its config files or querying its tooling.
protocol InvestigationProfile: Sendable {
    /// Process names this profile applies to (case-insensitive).
    var processNames: [String] { get }

    /// Bundle identifiers this profile applies to.
    var bundleIDs: [String] { get }

    /// Return a finding for this alert, or `nil` if nothing useful can be said.
    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding?
}

// MARK: - Profile Registry

enum InvestigationProfiles {
    static let `default`: [any InvestigationProfile] = [
        SyncthingProfile(),
        TailscaleProfile(),
        DockerProfile(),
        DropboxProfile(),
        ChromeProfile(),
        VSCodeProfile(),
        SpotifyProfile(),
        NextcloudProfile(),
        BackblazeProfile(),
        iCloudProfile(),
        VPNProfile(),
        SteamProfile(),
        DiscordProfile()
    ]
}

// MARK: - Helpers

private func homeRelative(_ path: String) -> URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path)
}

private func firstExisting(_ urls: [URL]) -> URL? {
    urls.first { FileManager.default.fileExists(atPath: $0.path) }
}

private func shell(_ executable: String, args: [String]) -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = args
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

// MARK: - Syncthing

struct SyncthingProfile: InvestigationProfile {
    let processNames = ["syncthing"]
    let bundleIDs: [String] = []

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let configURL: URL
        if let customHome = commandLine?.syncthingHome() {
            configURL = customHome.appendingPathComponent("config.xml")
        } else {
            configURL = firstExisting([
                homeRelative("Library/Application Support/Syncthing/config.xml"),
                homeRelative(".config/syncthing/config.xml")
            ]) ?? homeRelative("Library/Application Support/Syncthing/config.xml")
        }

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return ConfigFinding(
                source: "Syncthing config",
                detail: "No Syncthing config.xml found at the expected location."
            )
        }

        do {
            let xml = try XMLDocument(contentsOf: configURL)
            let deviceCount = (try? xml.nodes(forXPath: "//device").count) ?? 0
            let folderCount = (try? xml.nodes(forXPath: "//folder").count) ?? 0
            let deviceNames = (try? xml.nodes(forXPath: "//device/@name").compactMap { $0.stringValue }) ?? []

            var detail = "Config found at \(configURL.path)."
            if deviceCount > 0 {
                detail += " It defines \(deviceCount) device(s)"
                if !deviceNames.isEmpty {
                    detail += ": \(deviceNames.joined(separator: ", "))."
                } else {
                    detail += "."
                }
            }
            if folderCount > 0 {
                detail += " There are \(folderCount) shared folder(s)."
            }
            detail += " A connection on port \(alert.remotePort) is usually direct sync with one of these devices."
            return ConfigFinding(source: "Syncthing", detail: detail)
        } catch {
            return ConfigFinding(
                source: "Syncthing config",
                detail: "Found config at \(configURL.path) but could not parse it: \(error.localizedDescription)"
            )
        }
    }
}

private extension String {
    func syncthingHome() -> URL? {
        if let range = self.range(of: "-home=") {
            let after = self[range.upperBound...]
            let token = String(after.split(separator: " ").first ?? "")
            return URL(fileURLWithPath: (token as NSString).expandingTildeInPath)
        }
        if let range = self.range(of: "-home ") {
            let after = self[range.upperBound...]
            let token = String(after.split(separator: " ").first ?? "")
            return URL(fileURLWithPath: (token as NSString).expandingTildeInPath)
        }
        return nil
    }
}

// MARK: - Tailscale

struct TailscaleProfile: InvestigationProfile {
    let processNames = ["tailscale", "tailscaled", "tailscale-ipn"]
    let bundleIDs = ["io.tailscale.ipn.macos"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        guard let binary = tailscaleBinary(),
              let json = shell(binary, args: ["status", "--json"]),
              let data = json.data(using: .utf8) else {
            return nil
        }

        do {
            let status = try JSONDecoder().decode(TailscaleStatus.self, from: data)
            let tailnet = status.`self`.tailnetName ?? "your tailnet"

            // Direct peer match
            for peer in status.peer.values {
                if peer.tailscaleIPs.contains(alert.remoteAddress) {
                    let online = peer.online ? "online" : "offline"
                    return ConfigFinding(
                        source: "Tailscale",
                        detail: "Remote IP belongs to Tailscale peer '\(peer.hostName)' on \(tailnet) (\(online)). Traffic is routing through your tailnet."
                    )
                }
            }

            return ConfigFinding(
                source: "Tailscale",
                detail: "This machine is on Tailscale tailnet '\(tailnet)' (\(status.`self`.hostName)). The remote address is not a known peer, but it may be a Tailscale subnet router or exit node."
            )
        } catch {
            return ConfigFinding(
                source: "Tailscale",
                detail: "Tailscale is installed but its status could not be parsed: \(error.localizedDescription)"
            )
        }
    }

    private func tailscaleBinary() -> String? {
        let candidates = [
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/usr/local/bin/tailscale",
            "/opt/homebrew/bin/tailscale",
            "/usr/bin/tailscale"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) && FileManager.default.isExecutableFile(atPath: $0) }
    }
}

private struct TailscaleStatus: Decodable {
    struct SelfInfo: Decodable {
        let hostName: String
        let tailnetName: String?
        let tailscaleIPs: [String]
    }
    struct PeerInfo: Decodable {
        let hostName: String
        let tailscaleIPs: [String]
        let online: Bool
    }
    let `self`: SelfInfo
    let peer: [String: PeerInfo]

    enum CodingKeys: String, CodingKey {
        case `self` = "Self"
        case peer = "Peer"
    }
}

// MARK: - Docker

struct DockerProfile: InvestigationProfile {
    let processNames = ["docker", "com.docker.docker", "com.docker.backend"]
    let bundleIDs = ["com.docker.docker"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let configURL = homeRelative(".docker/config.json")
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ConfigFinding(
                source: "Docker",
                detail: "Docker config not found. This connection may be Docker pulling/pushing images or a container reaching the network."
            )
        }

        var parts: [String] = []
        if let auths = json["auths"] as? [String: Any], !auths.isEmpty {
            let registries = Array(auths.keys).sorted()
            parts.append("Configured registries: \(registries.joined(separator: ", ")).")
        }
        if let context = json["currentContext"] as? String, !context.isEmpty {
            parts.append("Active context: \(context).")
        }

        let detail = parts.isEmpty
            ? "Docker is installed. This connection is likely image/registry traffic or a container reaching the network."
            : parts.joined(separator: " ")
        return ConfigFinding(source: "Docker", detail: detail)
    }
}

// MARK: - Dropbox

struct DropboxProfile: InvestigationProfile {
    let processNames = ["dropbox"]
    let bundleIDs = ["com.getdropbox.dropbox"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let infoURL = homeRelative(".dropbox/info.json")
        guard FileManager.default.fileExists(atPath: infoURL.path),
              let data = try? Data(contentsOf: infoURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return ConfigFinding(
                source: "Dropbox",
                detail: "Dropbox is running. Connections to *.dropboxapi.com or Dropbox LAN sync are expected."
            )
        }

        var parts: [String] = []
        for (key, value) in json {
            if let path = value["path"] as? String {
                parts.append("\(key) sync folder at \(path)")
            }
        }
        let detail = parts.isEmpty
            ? "Dropbox is running. This connection is likely sync or LAN discovery traffic."
            : "Dropbox is running with \(parts.joined(separator: "; ")). This connection is likely sync traffic."
        return ConfigFinding(source: "Dropbox", detail: detail)
    }
}

// MARK: - Chrome / Chromium family

struct ChromeProfile: InvestigationProfile {
    let processNames = [
        "google chrome", "google chrome helper", "brave browser", "brave browser helper",
        "arc", "arc helper", "zen", "zen helper", "microsoft edge", "microsoft edge helper",
        "opera", "vivaldi"
    ]
    let bundleIDs: [String] = []

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let supportDir = homeRelative("Library/Application Support")
        let candidates = [
            supportDir.appendingPathComponent("Google/Chrome"),
            supportDir.appendingPathComponent("BraveSoftware/Brave-Browser"),
            supportDir.appendingPathComponent("Microsoft Edge"),
            supportDir.appendingPathComponent("Opera"),
            supportDir.appendingPathComponent("Vivaldi"),
            supportDir.appendingPathComponent("Arc")
        ]

        var extensionNames: [String] = []
        for base in candidates where FileManager.default.fileExists(atPath: base.path) {
            let extensionsDir = base.appendingPathComponent("Default/Extensions")
            extensionNames.append(contentsOf: installedExtensionNames(at: extensionsDir))
        }

        let unique = Array(Set(extensionNames)).sorted().prefix(8)
        if unique.isEmpty {
            return ConfigFinding(
                source: "Browser",
                detail: "A Chromium-family browser is running. This connection is likely a website, extension, or browser service."
            )
        }
        return ConfigFinding(
            source: "Browser extensions",
            detail: "Installed extensions that may cause network traffic: \(unique.joined(separator: ", "))."
        )
    }

    private func installedExtensionNames(at url: URL) -> [String] {
        guard let extIDs = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return [] }
        var names: [String] = []
        for extID in extIDs {
            let extDir = url.appendingPathComponent(extID)
            guard let versions = try? FileManager.default.contentsOfDirectory(atPath: extDir.path) else { continue }
            for version in versions {
                let manifest = extDir.appendingPathComponent("\(version)/manifest.json")
                if let data = try? Data(contentsOf: manifest),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let name = json["name"] as? String {
                    names.append(name)
                }
            }
        }
        return names
    }
}

// MARK: - VS Code / Cursor / Windsurf

struct VSCodeProfile: InvestigationProfile {
    let processNames = ["code", "code helper", "cursor", "cursor helper", "windsurf", "windsurf helper"]
    let bundleIDs = ["com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        var extensionCounts: [(String, Int)] = []
        let candidates = [
            homeRelative(".vscode/extensions"),
            homeRelative(".cursor/extensions"),
            homeRelative(".windsurf/extensions")
        ]
        for dir in candidates where FileManager.default.fileExists(atPath: dir.path) {
            let count = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.count ?? 0
            if count > 0 {
                extensionCounts.append((dir.lastPathComponent, count))
            }
        }

        if extensionCounts.isEmpty {
            return ConfigFinding(
                source: "Code editor",
                detail: "A VS Code-family editor is running. This connection may be from an extension, language server, or remote development session."
            )
        }

        let summary = extensionCounts.map { "\($0.0): \($0.1) extension(s)" }.joined(separator: "; ")
        return ConfigFinding(
            source: "Code editor extensions",
            detail: "\(summary). Extensions (remote SSH, Copilot, etc.) may connect to external services."
        )
    }
}

// MARK: - Spotify

struct SpotifyProfile: InvestigationProfile {
    let processNames = ["spotify", "spotifyhelper"]
    let bundleIDs = ["com.spotify.client"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        ConfigFinding(
            source: "Spotify",
            detail: "Spotify is running. Connections to Spotify's CDN, search, social, or Spotify Connect devices are expected."
        )
    }
}

// MARK: - Nextcloud

struct NextcloudProfile: InvestigationProfile {
    let processNames = ["nextcloud", "nextcloudcmd"]
    let bundleIDs = ["com.nextcloud.desktopclient"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let configURL = firstExisting([
            homeRelative("Library/Preferences/Nextcloud/nextcloud.cfg"),
            homeRelative("Library/Application Support/Nextcloud/nextcloud.cfg"),
            homeRelative(".config/Nextcloud/nextcloud.cfg")
        ])

        guard let url = configURL,
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ConfigFinding(
                source: "Nextcloud",
                detail: "Nextcloud client is running. This connection is likely sync traffic to a configured Nextcloud server."
            )
        }

        var servers: [String] = []
        var users: [String] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("\\url="), let value = line.components(separatedBy: "\\url=").last, !value.isEmpty {
                servers.append(value)
            }
            if line.contains("\\user="), let value = line.components(separatedBy: "\\user=").last, !value.isEmpty {
                users.append(value)
            }
        }

        var detail = "Nextcloud config found."
        if !servers.isEmpty {
            detail += " Configured server(s): \(servers.joined(separator: ", "))."
        }
        if !users.isEmpty {
            detail += " Account: \(users.joined(separator: ", "))."
        }
        detail += " This connection is likely file sync traffic."
        return ConfigFinding(source: "Nextcloud", detail: detail)
    }
}

// MARK: - Backblaze

struct BackblazeProfile: InvestigationProfile {
    let processNames = ["bzbmenu", "bzbzserv", "bzbui", "backblaze"]
    let bundleIDs = ["com.backblaze.Backblaze"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let plistURL = homeRelative("Library/Preferences/com.backblaze.Backblaze.plist")
        let hasPlist = FileManager.default.fileExists(atPath: plistURL.path)

        let detail = hasPlist
            ? "Backblaze is configured on this Mac. This connection is likely backup traffic to Backblaze's servers."
            : "Backblaze process is running. This connection is likely backup traffic to Backblaze's servers."
        return ConfigFinding(source: "Backblaze", detail: detail)
    }
}

// MARK: - iCloud / CloudKit

struct iCloudProfile: InvestigationProfile {
    let processNames = ["cloudd", "cloudphotod", "bird", "akd", "fmfd", "findmydevice-useragent", "fileproviderd"]
    let bundleIDs = ["com.apple.cloudd", "com.apple.cloudphotosd", "com.apple.bird", "com.apple.akd", "com.apple.findmy"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let service: String
        switch alert.processName.lowercased() {
        case "cloudd", "bird":
            service = "iCloud Drive file sync"
        case "cloudphotod":
            service = "iCloud Photos sync"
        case "akd":
            service = "Apple ID authentication / iCloud account validation"
        case "fmfd", "findmydevice-useragent":
            service = "Find My / device location services"
        case "fileproviderd":
            service = "Cloud file provider (iCloud Drive or third-party cloud storage)"
        default:
            service = "Apple iCloud / CloudKit service"
        }

        return ConfigFinding(
            source: "iCloud / CloudKit",
            detail: "This is an Apple system daemon responsible for \(service). Traffic to *.icloud.com, *.apple.com, or push notification servers is expected."
        )
    }
}

// MARK: - VPN clients

struct VPNProfile: InvestigationProfile {
    let processNames = [
        "protonvpn", "protonvpn helper", "nordvpn", "nordvpnd", "nordvpn helper",
        "wireguard", "wireguard-go", "openvpn", "tunnelblick", "windscribe",
        "pia", "private internet access", "expressvpn", "surfshark"
    ]
    let bundleIDs = [
        "ch.protonvpn.mac", "com.nordvpn.osx-app", "com.wireguard.macos",
        "net.tunnelblick.tunnelblick", "com.windscribe.gui", "com.privateinternetaccess.vpn",
        "com.expressvpn.ExpressVPN", "com.surfshark.vpn"
    ]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let tunnels = activeVPNTunnelInterfaces()
        if tunnels.isEmpty {
            return ConfigFinding(
                source: "VPN client",
                detail: "A VPN client is running. If a tunnel is not yet active, this may be the app checking for updates or logging in."
            )
        }
        return ConfigFinding(
            source: "VPN client",
            detail: "Active VPN tunnel interface(s): \(tunnels.joined(separator: ", ")). Traffic is routing through the VPN."
        )
    }

    private func activeVPNTunnelInterfaces() -> [String] {
        var interfaces: [String] = []
        var ifaddrsPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrsPtr) == 0 else { return interfaces }
        defer { freeifaddrs(ifaddrsPtr) }

        var ptr = ifaddrsPtr
        while let ifa = ptr {
            let name = String(cString: ifa.pointee.ifa_name)
            if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") || name.hasPrefix("tun") {
                interfaces.append(name)
            }
            ptr = ifa.pointee.ifa_next
        }
        return interfaces
    }
}

// MARK: - Steam

struct SteamProfile: InvestigationProfile {
    let processNames = ["steam", "steam helper", "steam_osx"]
    let bundleIDs = ["com.valvesoftware.steam"]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let libraryFolders = homeRelative("Library/Application Support/Steam/steamapps/libraryfolders.vdf")
        var libraryCount = 0
        if FileManager.default.fileExists(atPath: libraryFolders.path),
           let text = try? String(contentsOf: libraryFolders, encoding: .utf8) {
            libraryCount = text.components(separatedBy: .newlines).filter { $0.contains("\"path\"") }.count
        }

        var detail = "Steam client is running."
        if libraryCount > 0 {
            detail += " It has \(libraryCount) game library folder(s)."
        }
        detail += " This connection is likely Steam downloads, friends/chat, matchmaking, or cloud saves."
        return ConfigFinding(source: "Steam", detail: detail)
    }
}

// MARK: - Discord

struct DiscordProfile: InvestigationProfile {
    let processNames = ["discord", "discord helper", "discord ptb", "discord canary"]
    let bundleIDs = [
        "com.hnc.Discord",
        "com.hnc.DiscordPTB",
        "com.hnc.DiscordCanary"
    ]

    func finding(for alert: WANConnectionAlert, commandLine: String?, executablePath: String?) async -> ConfigFinding? {
        let prefsURL = homeRelative("Library/Preferences/com.hnc.Discord.plist")
        let hasPrefs = FileManager.default.fileExists(atPath: prefsURL.path)

        var detail = "Discord is running."
        if hasPrefs {
            detail += " User preferences found."
        }
        detail += " This connection is likely Discord gateway, voice, media, or update traffic."
        return ConfigFinding(source: "Discord", detail: detail)
    }
}
