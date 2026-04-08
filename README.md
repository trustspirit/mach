# Mach

A lightweight macOS menu bar app for real-time system monitoring and cleanup.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)

## Features

### System Monitor
- **CPU** — Total usage with per-core breakdown
- **RAM** — Used/total memory with usage history graph (active, inactive, wired, compressed, swap)
- **Disk** — Storage usage and real-time read/write speeds
- **GPU** — GPU utilization monitoring
- **Battery** — Charge level with color-coded alerts and charging status
- **Network** — Upload/download speed tracking

### System Cleaner
| Cleaner | Description |
|---------|-------------|
| Memory Purge | Frees inactive memory (requires privilege) |
| System Cache | Clears `~/Library/Caches` |
| Temp Files | Removes temp files older than 7 days |
| App Logs | Cleans `~/Library/Logs` |
| Xcode DerivedData | Removes `~/Library/Developer/Xcode/DerivedData` |
| Docker Prune | Cleans unused Docker resources (if installed) |
| Homebrew Cleanup | Runs `brew cleanup` (if installed) |
| DNS Cache | Flushes the DNS cache |
| Package Cache | Cleans npm/yarn/pip caches |

### Menu Bar
- Animated RAM equalizer bars with color-coded usage levels
- Battery gauge with charging indicator
- Auto-syncs with system light/dark mode

### Alerts
Configurable threshold notifications for CPU, RAM, Disk, Battery, and Temperature.

## Install

### Download (Recommended)

1. Go to [Releases](../../releases/latest)
2. Download `Mach-x.x.x-mac.dmg`
3. Open the DMG and drag **Mach** to `/Applications`
4. **Before first launch**, open Terminal and run:
   ```bash
   xattr -cr /Applications/Mach.app
   ```
   Or: right-click the app → **Open** → click **Open** in the dialog

> **Why is this needed?**  
> Mach is not notarized with Apple. macOS Gatekeeper blocks unnotarized apps by default. The command above removes the quarantine flag so the app can launch normally. This only needs to be done once.

### Build from Source

**Requirements:** Xcode 15.0+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
# Clone
git clone https://github.com/5anthrope/Mach.git
cd Mach

# Generate Xcode project and build
xcodegen generate
./scripts/build.sh

# Output: build/Mach.dmg
```

## Usage

Mach runs as a **menu bar app** — there is no Dock icon.

1. Launch Mach. A small icon appears in the menu bar.
2. Click the icon to open the dashboard panel.
3. Use the dashboard to view system metrics or run cleaners.
4. Press **ESC** or click outside to close the panel.

### Settings

- **Launch at Login** — Start Mach automatically on login
- **Appearance** — Follows system light/dark mode

## Requirements

- macOS 14.0 (Sonoma) or later

## License

MIT
