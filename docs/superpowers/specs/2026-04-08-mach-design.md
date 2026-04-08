# Mach - macOS Menu Bar System Monitor & Cleaner

## Overview

Mach is a native macOS menu bar app that provides real-time system monitoring (CPU, GPU, RAM, Disk, Network, Battery) and cleaning utilities for developers and power users. The name references the macOS Mach kernel and evokes speed/performance.

## Target Users

Developers and power users who want detailed system metrics and developer-specific cleanup tools.

## Tech Stack

- **Swift + SwiftUI** for UI (popover, settings, detail views)
- **AppKit** for menu bar integration (`NSStatusItem`, `NSPopover`)
- **System APIs:** `sysctl`, `IOKit`, `host_statistics64()`, `getifaddrs()`, `IOPowerSources`
- **Minimum target:** macOS 14 (Sonoma)

## Architecture

Single-process monolith. No helper tool separation — privilege escalation handled via AppleScript when needed.

```
Mach.app
├── MachApp.swift                 # @main, NSApplicationDelegateAdaptor
├── AppDelegate.swift             # NSStatusItem, NSPopover lifecycle
├── Views/
│   ├── DashboardView.swift       # Main 2x2 grid + network/battery
│   ├── Tiles/
│   │   ├── CPUTileView.swift
│   │   ├── GPUTileView.swift
│   │   ├── RAMTileView.swift
│   │   ├── DiskTileView.swift
│   │   ├── NetworkTileView.swift
│   │   └── BatteryTileView.swift
│   ├── DetailViews/
│   │   ├── CPUDetailView.swift
│   │   ├── GPUDetailView.swift
│   │   ├── RAMDetailView.swift
│   │   ├── DiskDetailView.swift
│   │   ├── NetworkDetailView.swift
│   │   └── BatteryDetailView.swift
│   ├── CleanerView.swift         # Individual purge buttons per item
│   └── SettingsView.swift        # Preferences
├── Monitors/
│   ├── MonitorManager.swift      # Smart timer management
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── RAMMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   └── BatteryMonitor.swift
├── Cleaners/
│   ├── CleanerManager.swift      # Clean task orchestration
│   ├── MemoryCleaner.swift
│   ├── CacheCleaner.swift
│   ├── DNSCleaner.swift
│   ├── XcodeCleaner.swift
│   ├── DockerCleaner.swift
│   ├── BrewCleaner.swift
│   └── PackageCleaner.swift
├── Utilities/
│   ├── ShellExecutor.swift       # Process-based command execution
│   ├── PrivilegeHelper.swift     # AppleScript privilege escalation
│   └── NotificationManager.swift # Threshold alerts
└── Models/
    ├── SystemMetrics.swift
    └── CleanResult.swift
```

## Menu Bar

- **Icon only** — no text or graphs in the menu bar
- Click opens `NSPopover` with `DashboardView`
- Custom SF Symbol or minimal app icon

## Popover UI (Dashboard)

Popover size: ~320 x 480pt.

### Layout

```
┌─ Header ───────────────────────────────────┐
│  Mach                    [Clean] [Settings] [Quit] │
├────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐               │
│  │ CPU  23% │  │ GPU  45% │               │
│  │ ████░░░  │  │ █████░░  │               │
│  └──────────┘  └──────────┘               │
│  ┌──────────┐  ┌──────────┐               │
│  │ RAM  67% │  │ DISK 52% │               │
│  │ █████░░  │  │ ████░░░  │               │
│  └──────────┘  └──────────┘               │
│  ┌──────────────────────────┐             │
│  │ NET   ↑1.2MB/s  ↓5.4MB/s│             │
│  └──────────────────────────┘             │
│  ┌──────────────────────────┐             │
│  │ BATTERY  87%  ⚡ Charging │             │
│  │ [Low Power] [Auto ●] [High Performance]│
│  │ ⬆ Full Charge              [Run]      │
│  └──────────────────────────┘             │
└────────────────────────────────────────────┘
```

### Navigation

- **Clean button** → CleanerView (back button to return)
- **Settings button** → SettingsView
- **Quit button** → Terminate app
- **Tile click** → Detail view with 60-second history graph + breakdown

## Monitoring

### Data Sources

| Monitor | Data | API |
|---------|------|-----|
| CPU | Overall %, per-core %, temperature | `host_processor_info()`, IOKit SMC |
| GPU | Usage %, VRAM, temperature | IOKit `IOAccelerator` |
| RAM | Used/total, compressed, swap, wired/active/inactive | `host_statistics64()` |
| Disk | Used/total, read/write speed | `FileManager`, IOKit `IOBlockStorageDriver` |
| Network | Upload/download speed, active interface | `getifaddrs()`, delta calculation |
| Battery | Charge %, charging/discharging/full status, cycle count, health, time remaining | `IOPowerSources`, IOKit SMC |

### Smart Timer (MonitorManager)

- **Popover open:** 1-second interval — all monitors refresh
- **Popover closed:** 10-second interval — threshold checks only
- Transition managed by `NSPopover` delegate callbacks

### Alert Thresholds (defaults)

| Metric | Threshold |
|--------|-----------|
| CPU | > 90% sustained for 30 seconds |
| RAM | > 90% |
| Disk | > 95% |
| Battery | < 15% |
| Temperature (CPU/GPU) | > 95 C |

Alerts delivered via `UNUserNotificationCenter` (macOS native notifications).

## Battery Tile (Extended)

### States

| State | Display | Full Charge Button |
|-------|---------|-------------------|
| Charging (< 80%) | ⚡ Charging | Disabled |
| Optimized hold (80%) | ⏸ Holding at 80% | **Enabled** — triggers full charge |
| Charging (80-100%) | ⚡ Full charging | Disabled (in progress) |
| Full | ✓ Fully charged | Hidden |
| Discharging | 🔋 Remaining: X:XX | Hidden (no power) |

### Energy Mode Switcher

Segmented control with three modes:
- **Low Power** — `pmset -c lowpowermode 1`
- **Automatic** — default mode
- **High Performance** — `pmset -c highpowermode 1`

Current mode detected via `pmset -g`. Mode switching requires privilege escalation.

## Cleaner

### UI Pattern

Each item has its own row with size display and independent action button. No checkboxes.

```
┌─ CleanerView ──────────────────────────────┐
│  ← Back                                    │
│                                            │
│  ⚡ Quick Clean                    [Run]   │
│     Est. recovery: ~2.3 GB                 │
│  ──────────────────────────────────        │
│  System Cache          1.2 GB    [Clean]   │
│  App Logs              340 MB    [Clean]   │
│  Temp Files            890 MB    [Clean]   │
│  DNS Cache               —       [Flush]   │
│  Memory                  —       [Purge]   │
│  ─── Developer Tools ──────────            │
│  Xcode DerivedData     4.5 GB    [Clean]   │
│  Docker Unused         2.1 GB    [Clean]   │
│  Homebrew Cache        1.8 GB    [Clean]   │
│  npm Cache             520 MB    [Clean]   │
│  yarn Cache            280 MB    [Clean]   │
│  pip Cache             160 MB    [Clean]   │
└────────────────────────────────────────────┘
```

### Clean Items

| Item | Target | Privilege |
|------|--------|-----------|
| Memory Purge | `sudo purge` | root |
| System Cache | `~/Library/Caches/*` | user |
| App Logs | `~/Library/Logs/*` | user |
| Temp Files | `/tmp/*`, `$TMPDIR` | user |
| DNS Cache | `sudo dscacheutil -flushcache` + `sudo killall -HUP mDNSResponder` | root |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData/*` | user |
| Homebrew Cache | `brew cleanup --prune=all` | user |
| Docker Cleanup | `docker system prune -f` | user |
| npm Cache | `npm cache clean --force` | user |
| yarn Cache | `yarn cache clean` | user |
| pip Cache | `pip cache purge` | user |

### Safety

- **Pre-scan sizes** — show estimated recoverable space before running
- **Per-item execution** — each button runs independently, shows spinner → result
- **Completion feedback** — button changes to "✓ X MB freed" after success
- **Tool detection** — disable items for uninstalled tools (Docker, Homebrew, etc.)
- **Quick Clean** — only runs safe items: system cache + app logs + temp files + memory purge

## Settings

- Launch at login (on/off)
- Threshold alerts (on/off)
- Per-metric threshold customization (CPU %, RAM %, Disk %, Battery %, Temperature)
- App info / version

## Visual Style

- **System-linked** — follows macOS dark/light mode automatically
- Uses `@Environment(\.colorScheme)` for adaptive colors
- Accent colors per metric: CPU (cyan), GPU (pink), RAM (purple), Disk (blue), Network (teal), Battery (green)

## Non-Goals

- No process management / kill functionality
- No App Store distribution (initial release)
- No cross-platform support
- No automatic cleaning (user-initiated only)
- No historical data persistence beyond current session
