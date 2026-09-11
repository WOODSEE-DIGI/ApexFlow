# Contributing to Apex

Thank you for your interest in contributing! Apex is built in Swift 6 / SwiftUI and targets macOS 14+.

## Getting Started

### Prerequisites
- macOS 14.0 or later
- Xcode 16.0 or later
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Build

```bash
git clone https://github.com/WOODSEE-DIGI/ApexFlow.git
cd Apex
xcodegen generate
open Apex.xcodeproj
```

Press **⌘R** in Xcode to build and run. The app requires no signing for local development — set `CODE_SIGNING_REQUIRED=NO` if building from the command line.

## Project Structure

See the [Architecture section in README.md](README.md#architecture) for a full overview.

The key pattern to understand:

- **Collectors** are Swift `actor` types. They collect system data and return `Sendable` structs.
- **Data models** are `@Observable @MainActor` classes. They hold the live state that SwiftUI observes.
- **SystemMonitor** is the `@MainActor` coordinator that runs polling loops and feeds snapshots from Collectors into Models.
- **Views** are standard SwiftUI views. They read from Models; they never call Collectors directly.

## Code Style

- Swift 6 strict concurrency is enforced (`SWIFT_STRICT_CONCURRENCY = complete`). All new code must compile cleanly with no concurrency warnings.
- Follow the existing naming conventions — `XxxCollector`, `XxxData`, `XxxSnapshot`, `XxxView`.
- Keep Collectors free of SwiftUI imports. Keep Views free of Darwin/IOKit imports.
- Use `@unchecked Sendable` only when wrapping a C callback or system framework that cannot be made Sendable — document *why* with a comment.
- Prefer `actor` over `DispatchQueue` for new concurrency.

## Adding a New Panel

1. Create `Apex/Models/XxxData.swift` — `@Observable @MainActor` class + `Sendable` snapshot struct.
2. Create `Apex/Collectors/XxxCollector.swift` — `actor` with a `collect()` method.
3. Create `Apex/Views/XxxView.swift` — SwiftUI view.
4. Wire it in `SystemMonitor.swift` — add a polling task with an appropriate interval.
5. Add the view to `ContentView.swift`.

## Pull Requests

- Branch from `main`, use a descriptive name: `feat/gpu-panel`, `fix/midi-sysex`, `docs/readme-screenshot`.
- Keep PRs focused — one feature or fix per PR.
- Include a brief description of what changed and why.
- The CI workflow runs `xcodebuild` on every PR — your branch must compile cleanly before review.

## Good First Issues

| Area | What's needed |
|---|---|
| App icon | 1024×1024 icon + all required sizes in an `.xcassets` set |
| GPU panel | Apple GPU stats via IOKit / Metal Performance Shaders |
| SMC temperatures | Apple Silicon die temperature via SMC / private framework |
| Theme switcher | Light mode / dark mode toggle using Theme.swift tokens |
| Configurable OSC port | User preference for the UDP listen port (currently hardcoded 8000) |
| App Store sandbox | SMJobBless helper for process kill + entitlement audit |
| iOS companion | SwiftUI app sharing the same Models layer for iPhone/iPad |

## Reporting Bugs

Please use the GitHub Issues tab. Include:
- macOS version
- Xcode version (if building from source)
- Steps to reproduce
- What you expected vs what happened
- Console output if relevant (`Console.app` → filter for "Apex")
