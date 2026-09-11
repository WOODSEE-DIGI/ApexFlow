# Apex Flow

[![Build](https://github.com/WOODSEE-DIGI/ApexFlow/actions/workflows/build.yml/badge.svg)](https://github.com/WOODSEE-DIGI/ApexFlow/actions/workflows/build.yml)
[![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/github/license/WOODSEE-DIGI/ApexFlow)](LICENSE)

**A native macOS system monitor built in Swift 6 / SwiftUI.**

Apex Flow is a full-featured, open-source replacement for btop, designed specifically for macOS with native access to Apple frameworks. It monitors CPU, memory, disks, network, processes, storage health, AI model activity, and — uniquely — provides real-time visibility into Thunderbolt ports, USB peripherals, Bluetooth devices, MIDI hardware, and OSC network streams.

Panels live on a draggable, resizable canvas and the entire colour scheme can be customised with built-in presets or your own palette.

---

## Screenshots

| Main dashboard | Panel picker |
|---|---|
| ![Apex Flow main dashboard](Screenshots/ApexFlow-Main%20Ui.png) | ![Apex Flow panel picker](Screenshots/ApexFlow-Show%20Panels.png) |

| Theme presets | Theme customisation |
|---|---|
| ![Apex Flow theme presets](Screenshots/ApexFlow-Themes-1.png) | ![Apex Flow theme customisation](Screenshots/ApexFlow-Themes-2.png) |

---

## Features

### Canvas Workspace
- **Draggable, resizable panels** — Arrange CPU, Memory & Disks, Network, Connectivity, AI Model, Processes, and Storage Health however you like
- **Persistent layout** — Your panel positions and sizes are saved between launches
- **Lock / unlock** — Toggle editing mode to prevent accidental moves
- **Panel picker** — Show or hide any panel from the toolbar

### Themes
- **20 built-in presets** — Matrix, Cyberpunk Neon, Hello Kitty Pinks, Rainbows and Unicorns, Clean and Minimal, Professional, btop Tokyo Night, Nord, Solarized, One Dark, Monokai, and more
- **Custom colours** — Override accent, background, surface, text, and secondary text
- **Data colours** — Adjust load indicators (high / medium / low) and semantic palette colours (blue, teal, sky, mauve, pink, peach)
- **Light and dark appearance** — Per-theme appearance mode or follow the system

### System Monitoring
- **CPU** — Per-core usage grid with animated 60-second history chart, load averages (1/5/15 min), uptime, and CPU name
- **Memory** — Stacked usage bar (used / cached / free / swap) with usage history
- **Disks** — All drives with percentage meters, read/write rates, and dual-colour I/O sparklines. Supports Apple Software RAID sets, Thunderbolt RAID enclosures, and any connected storage (including DJI cameras)
- **Network** — Per-interface area charts (download / upload mirrored). Compact interface picker filtered to real adapters only
- **Processes** — Sortable, filterable process list with PID, CPU%, memory, threads and status. Right-click to send SIGTERM or SIGKILL
- **Storage Health** — S.M.A.R.T. status, health scores, temperature, power-on hours, filesystem verification, FileVault/encryption status, and Time Machine backup age
- **AI Model** — Real-time monitoring of SwiftMaestro/LM Studio token telemetry, streaming state, silent-period detection, and recent tool calls

### Connectivity Panel
- **WiFi** — SSID, signal bars, RSSI (dBm), link rate, channel, band (2.4 / 5 / 6 GHz), security
- **Bluetooth** — Connected devices with type icons, RSSI signal bars
- **Thunderbolt** — All ports enumerated via `system_profiler`, showing negotiated link speed (≤40G / 40G), protocol mode (TB3 / TB4 / USB4), connected device name, and live I/O activity sparklines
- **USB** — Full device list via `IOUSBHostDevice`, with speed-coded badges (USB4 / SS+ / SS / HS / FS / LS) and vendor names
- **MIDI** — Live CoreMIDI monitoring with 16-channel activity grid per device and decoded message display (Note On/Off, CC, Program Change, Pitchbend)
- **OSC** — Open Sound Control listener on UDP port 8000, with real-time decoded message log

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0 Sonoma or later |
| Xcode | 16.0 or later |
| Swift | 6.0 |

---

## Building from Source

```bash
# Clone
git clone https://github.com/WOODSEE-DIGI/ApexFlow.git
cd ApexFlow

# Install xcodegen (if not already installed)
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open in Xcode and run (⌘R)
open ApexFlow.xcodeproj
```

The project is managed with [xcodegen](https://github.com/yonaskolb/XcodeGen) from `project.yml`. `ApexFlow.xcodeproj` is regenerated after any structural change.

### First Run Permissions

On first launch, macOS will prompt for:
- **Bluetooth** — to display connected BT devices and RSSI
- **Location** — required by macOS to read the WiFi network name (SSID) via CoreWLAN

---

## Architecture

Apex Flow uses Swift 6 strict concurrency throughout.

```
Apex/
├── App/
│   ├── ApexApp.swift                # @main entry point, WindowGroup
│   ├── ContentView.swift            # Toolbar + canvas workspace host
│   ├── SystemMonitor.swift          # @MainActor coordinator, manages all polling tasks
│   └── HelperManager.swift          # SMAppService privileged helper bridge
├── Collectors/                      # Swift actors — data collection off main thread
│   ├── CPUCollector.swift
│   ├── MemoryCollector.swift
│   ├── DiskCollector.swift
│   ├── NetworkCollector.swift
│   ├── ProcessCollector.swift
│   ├── ConnCollector.swift
│   ├── OSCCollector.swift
│   └── AIModelCollector.swift       # Observes SwiftMaestro token notifications
├── Models/
│   ├── CPUData.swift
│   ├── MemoryData.swift
│   ├── DiskData.swift
│   ├── NetworkData.swift
│   ├── ProcessData.swift
│   ├── ConnData.swift
│   ├── AIModelData.swift
│   ├── DiskHealth.swift
│   ├── ApexPanelKind.swift          # Panel identifiers
│   ├── ApexWorkspaceLayoutState.swift # Canvas tile layout persistence
│   └── ThemePreset.swift            # Built-in theme definitions
├── Services/
│   ├── ThemeStore.swift             # User-customisable colour overrides
│   └── DiskHealthService.swift      # SMART + filesystem health snapshots
├── Views/
│   ├── ApexCanvasWorkspaceView.swift # Draggable/resizable canvas
│   ├── ApexPanelContainer.swift     # Panel chrome + header
│   ├── ApexPanelContentView.swift   # Panel kind → view routing
│   ├── CPUView.swift
│   ├── MemoryView.swift
│   ├── NetworkView.swift
│   ├── ConnView.swift
│   ├── ProcessView.swift
│   ├── DiskHealthView.swift
│   ├── AIModelView.swift
│   └── ThemeSettingsView.swift
└── Shared/
    ├── Theme.swift                  # Effective colour tokens + contrast helpers
    ├── SharedViews.swift            # MeterView, SparklineView, SignalBarView, SpeedBadge
    └── HelperProtocol.swift         # XPC helper protocol
```

### Data Flow

```
Actor Collectors ──await──► @MainActor @Observable Models ──► SwiftUI Views
     │                              │
     │                              └── SystemMonitor.correlateTBActivity()
     │                                  (disk I/O → Thunderbolt port histories)
     └── Thread-safe @unchecked Sendable buffers (NSLock)
         for CoreMIDI callbacks and NWListener datagrams
```

### Frameworks Used

| Framework | Purpose |
|---|---|
| SwiftUI + Swift Charts | All UI and animated graphs |
| Darwin / mach | CPU, memory, process data |
| IOKit | Disk I/O stats, USB enumeration, Thunderbolt |
| CoreWLAN | WiFi SSID, RSSI, link rate, channel |
| IOBluetooth | Connected BT device enumeration |
| CoreMIDI | MIDI device discovery and message capture |
| Network | OSC UDP listener (NWListener) |

---

## OSC Integration

Apex listens for Open Sound Control messages on **UDP port 8000** by default. Send from any OSC-capable app (TouchOSC, Max/MSP, SuperCollider, etc.):

```
Target IP:   your Mac's IP address
Port:        8000 (UDP)
```

Supported type tags: `i` (int32), `f` (float32), `d` (float64), `s` (string), `b` (blob), `T` (true), `F` (false), `N` (nil), `I` (impulse), `m` (MIDI), `#bundle`

---

## Known Limitations

- **Process kill** requires the app to run unsandboxed. This prevents Mac App Store distribution in the current build (see [App Store Roadmap](#app-store-roadmap))
- **WiFi SSID** requires location services — macOS 14+ enforces this for CoreWLAN
- **Thunderbolt I/O sparklines** show aggregated external disk throughput distributed across storage ports, not per-port exact throughput (macOS does not expose per-TB-port bandwidth in user space)
- **USB throughput** is not available per-device from user space; speed badges show negotiated bus speed only

---

## App Store Roadmap

To distribute on the Mac App Store, the following changes are needed:

1. **Enable sandbox** (`com.apple.security.app-sandbox = true`)
2. **Process kill** → replace `Darwin.kill()` with an [SMJobBless](https://developer.apple.com/documentation/servicemanagement/updating_your_app_package_installer_to_use_the_new_api) privileged helper tool, or remove the feature from the App Store build
3. **IOKit entitlements** → `com.apple.security.device.usb` for USB enumeration may be required
4. **Bluetooth entitlement** → confirm `com.apple.security.device.bluetooth` or equivalent
5. **App icon** → full 1024×1024 icon set required
6. **DEVELOPMENT_TEAM** → set your Apple Developer account team ID in `project.yml`
7. **App Store Connect** → create listing, screenshots, metadata, privacy manifest

Contributions towards App Store compatibility are very welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Contributing

Pull requests are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Good first issues:**
- App icon refinement
- GPU panel (Metal Performance Shaders stats)
- SMC temperature readings for Apple Silicon
- Configurable OSC port
- iOS / iPadOS companion app
- Additional theme presets

---

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — see [LICENSE](LICENSE).

This software is free for noncommercial use, including personal projects, hobby use, research, and education. Commercial use requires a separate license.
