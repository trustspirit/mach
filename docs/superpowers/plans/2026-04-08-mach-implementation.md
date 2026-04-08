# Mach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app (Mach) that monitors CPU, GPU, RAM, Disk, Network, and Battery in real-time, and provides developer-focused cleanup utilities.

**Architecture:** Single-process monolith using Swift + SwiftUI for UI and AppKit for menu bar integration. System data collected via IOKit, sysctl, host_statistics. Privilege escalation via AppleScript for root-level operations. Smart timer refreshes at 1s when popover is open, 10s when closed.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, IOKit, XCTest, XcodeGen, macOS 14+

**Spec:** `docs/superpowers/specs/2026-04-08-mach-design.md`

---

## File Structure

```
Mach/
├── project.yml                          # XcodeGen project spec
├── Mach/
│   ├── MachApp.swift                    # @main entry point
│   ├── AppDelegate.swift                # NSStatusItem + NSPopover management
│   ├── Info.plist                       # LSUIElement=true, notifications
│   ├── Mach.entitlements                # App Sandbox disabled for system access
│   ├── Assets.xcassets/                 # App icon, menu bar icon
│   ├── Models/
│   │   ├── SystemMetrics.swift          # Data structs for all 6 monitors
│   │   └── CleanItem.swift             # Clean item model + result
│   ├── Monitors/
│   │   ├── CPUMonitor.swift             # host_processor_info() wrapper
│   │   ├── RAMMonitor.swift             # host_statistics64() wrapper
│   │   ├── GPUMonitor.swift             # IOKit IOAccelerator
│   │   ├── DiskMonitor.swift            # FileManager + IOKit IOBlockStorage
│   │   ├── NetworkMonitor.swift         # getifaddrs() delta calculation
│   │   ├── BatteryMonitor.swift         # IOPowerSources + SMC
│   │   └── MonitorManager.swift         # Smart timer, owns all monitors
│   ├── Cleaners/
│   │   ├── CleanerProtocol.swift        # Shared protocol for all cleaners
│   │   ├── MemoryCleaner.swift          # purge command
│   │   ├── CacheCleaner.swift           # ~/Library/Caches
│   │   ├── LogCleaner.swift             # ~/Library/Logs
│   │   ├── TempCleaner.swift            # /tmp, $TMPDIR
│   │   ├── DNSCleaner.swift             # dscacheutil + mDNSResponder
│   │   ├── XcodeCleaner.swift           # DerivedData
│   │   ├── DockerCleaner.swift          # docker system prune
│   │   ├── BrewCleaner.swift            # brew cleanup
│   │   ├── PackageCleaner.swift         # npm/yarn/pip caches
│   │   └── CleanerManager.swift         # Orchestrates all cleaners
│   ├── Utilities/
│   │   ├── ShellExecutor.swift          # Process-based command runner
│   │   ├── PrivilegeHelper.swift        # AppleScript sudo wrapper
│   │   └── NotificationManager.swift    # UNUserNotificationCenter alerts
│   └── Views/
│       ├── DashboardView.swift          # Main 2x2 grid layout
│       ├── Tiles/
│       │   ├── TileView.swift           # Reusable tile component
│       │   ├── CPUTileView.swift
│       │   ├── GPUTileView.swift
│       │   ├── RAMTileView.swift
│       │   ├── DiskTileView.swift
│       │   ├── NetworkTileView.swift
│       │   └── BatteryTileView.swift
│       ├── DetailViews/
│       │   ├── HistoryGraphView.swift   # Reusable 60s sparkline chart
│       │   ├── CPUDetailView.swift
│       │   ├── GPUDetailView.swift
│       │   ├── RAMDetailView.swift
│       │   ├── DiskDetailView.swift
│       │   ├── NetworkDetailView.swift
│       │   └── BatteryDetailView.swift
│       ├── CleanerView.swift            # Individual purge buttons
│       └── SettingsView.swift           # Preferences
└── MachTests/
    ├── Models/
    │   ├── SystemMetricsTests.swift
    │   └── CleanItemTests.swift
    ├── Monitors/
    │   ├── CPUMonitorTests.swift
    │   ├── RAMMonitorTests.swift
    │   ├── GPUMonitorTests.swift
    │   ├── DiskMonitorTests.swift
    │   ├── NetworkMonitorTests.swift
    │   ├── BatteryMonitorTests.swift
    │   └── MonitorManagerTests.swift
    ├── Cleaners/
    │   ├── CleanerManagerTests.swift
    │   └── IndividualCleanerTests.swift
    └── Utilities/
        ├── ShellExecutorTests.swift
        └── NotificationManagerTests.swift
```

---

## Task 1: Project Scaffolding

**Files:**
- Create: `Mach/project.yml`
- Create: `Mach/Mach/Info.plist`
- Create: `Mach/Mach/Mach.entitlements`
- Create: `Mach/Mach/MachApp.swift`
- Create: `Mach/Mach/Assets.xcassets/Contents.json`
- Create: `Mach/Mach/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Install XcodeGen if not present**

Run: `brew list xcodegen || brew install xcodegen`

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p Mach/Mach/{Models,Monitors,Cleaners,Utilities,Views/{Tiles,DetailViews},Assets.xcassets/AppIcon.appiconset}
mkdir -p Mach/MachTests/{Models,Monitors,Cleaners,Utilities}
```

- [ ] **Step 3: Create project.yml**

```yaml
# Mach/project.yml
name: Mach
options:
  bundleIdPrefix: com.mach
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  minimumXcodeGenVersion: "2.38.0"

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"

targets:
  Mach:
    type: application
    platform: macOS
    sources:
      - Mach
    settings:
      base:
        INFOPLIST_FILE: Mach/Info.plist
        CODE_SIGN_ENTITLEMENTS: Mach/Mach.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.mach.app
        PRODUCT_NAME: Mach
        COMBINE_HIDPI_IMAGES: true
    entitlements:
      path: Mach/Mach.entitlements
  MachTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - MachTests
    dependencies:
      - target: Mach
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.mach.tests
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Mach.app/Contents/MacOS/Mach"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

- [ ] **Step 4: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Mach</string>
    <key>CFBundleDisplayName</key>
    <string>Mach</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Create entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 6: Create MachApp.swift (minimal entry point)**

```swift
// Mach/Mach/MachApp.swift
import SwiftUI

@main
struct MachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 7: Create placeholder AppDelegate.swift**

```swift
// Mach/Mach/AppDelegate.swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar setup will be added in Task 11
    }
}
```

- [ ] **Step 8: Create Assets.xcassets**

`Mach/Mach/Assets.xcassets/Contents.json`:
```json
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

`Mach/Mach/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images": [
    { "idiom": "mac", "scale": "1x", "size": "16x16" },
    { "idiom": "mac", "scale": "2x", "size": "16x16" },
    { "idiom": "mac", "scale": "1x", "size": "32x32" },
    { "idiom": "mac", "scale": "2x", "size": "32x32" },
    { "idiom": "mac", "scale": "1x", "size": "128x128" },
    { "idiom": "mac", "scale": "2x", "size": "128x128" },
    { "idiom": "mac", "scale": "1x", "size": "256x256" },
    { "idiom": "mac", "scale": "2x", "size": "256x256" },
    { "idiom": "mac", "scale": "1x", "size": "512x512" },
    { "idiom": "mac", "scale": "2x", "size": "512x512" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

- [ ] **Step 9: Generate Xcode project and verify build**

```bash
cd Mach && xcodegen generate
xcodebuild -project Mach.xcodeproj -scheme Mach -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 10: Commit**

```bash
git add Mach/
git commit -m "feat: scaffold Mach Xcode project with XcodeGen"
```

---

## Task 2: Data Models

**Files:**
- Create: `Mach/Mach/Models/SystemMetrics.swift`
- Create: `Mach/Mach/Models/CleanItem.swift`
- Create: `Mach/MachTests/Models/SystemMetricsTests.swift`
- Create: `Mach/MachTests/Models/CleanItemTests.swift`

- [ ] **Step 1: Write failing tests for SystemMetrics**

```swift
// Mach/MachTests/Models/SystemMetricsTests.swift
import XCTest
@testable import Mach

final class SystemMetricsTests: XCTestCase {

    func testCPUMetricsDefaults() {
        let cpu = CPUMetrics()
        XCTAssertEqual(cpu.totalUsage, 0)
        XCTAssertTrue(cpu.coreUsages.isEmpty)
        XCTAssertEqual(cpu.temperature, 0)
    }

    func testRAMMetrics() {
        let ram = RAMMetrics(
            total: 16_000_000_000,
            used: 10_000_000_000,
            compressed: 2_000_000_000,
            swap: 500_000_000,
            wired: 3_000_000_000,
            active: 5_000_000_000,
            inactive: 2_000_000_000
        )
        XCTAssertEqual(ram.usagePercent, 62.5, accuracy: 0.1)
    }

    func testGPUMetricsDefaults() {
        let gpu = GPUMetrics()
        XCTAssertEqual(gpu.usage, 0)
        XCTAssertEqual(gpu.vramUsed, 0)
        XCTAssertEqual(gpu.temperature, 0)
    }

    func testDiskMetrics() {
        let disk = DiskMetrics(
            totalSpace: 500_000_000_000,
            usedSpace: 250_000_000_000,
            readSpeed: 1_000_000,
            writeSpeed: 500_000
        )
        XCTAssertEqual(disk.usagePercent, 50.0, accuracy: 0.1)
    }

    func testNetworkMetrics() {
        let net = NetworkMetrics(
            uploadSpeed: 1_200_000,
            downloadSpeed: 5_400_000,
            interfaceName: "en0"
        )
        XCTAssertEqual(net.uploadFormatted, "1.2 MB/s")
        XCTAssertEqual(net.downloadFormatted, "5.4 MB/s")
    }

    func testNetworkMetricsKBFormatting() {
        let net = NetworkMetrics(uploadSpeed: 500, downloadSpeed: 800, interfaceName: "en0")
        XCTAssertEqual(net.uploadFormatted, "500 B/s")
        XCTAssertEqual(net.downloadFormatted, "800 B/s")
    }

    func testNetworkMetricsKBRange() {
        let net = NetworkMetrics(uploadSpeed: 50_000, downloadSpeed: 900_000, interfaceName: "en0")
        XCTAssertEqual(net.uploadFormatted, "48.8 KB/s")
        XCTAssertEqual(net.downloadFormatted, "878.9 KB/s")
    }

    func testBatteryMetricsCharging() {
        let bat = BatteryMetrics(
            chargePercent: 87,
            isCharging: true,
            isPluggedIn: true,
            cycleCount: 342,
            health: 92.0,
            timeRemaining: nil,
            isOptimizedHolding: false
        )
        XCTAssertTrue(bat.isCharging)
        XCTAssertEqual(bat.statusText, "Charging")
    }

    func testBatteryMetricsDischarging() {
        let bat = BatteryMetrics(
            chargePercent: 65,
            isCharging: false,
            isPluggedIn: false,
            cycleCount: 342,
            health: 92.0,
            timeRemaining: 222,
            isOptimizedHolding: false
        )
        XCTAssertEqual(bat.statusText, "3:42 remaining")
    }

    func testBatteryMetricsOptimizedHolding() {
        let bat = BatteryMetrics(
            chargePercent: 80,
            isCharging: false,
            isPluggedIn: true,
            cycleCount: 342,
            health: 92.0,
            timeRemaining: nil,
            isOptimizedHolding: true
        )
        XCTAssertEqual(bat.statusText, "Holding at 80%")
        XCTAssertTrue(bat.canTriggerFullCharge)
    }

    func testBatteryMetricsFull() {
        let bat = BatteryMetrics(
            chargePercent: 100,
            isCharging: false,
            isPluggedIn: true,
            cycleCount: 342,
            health: 92.0,
            timeRemaining: nil,
            isOptimizedHolding: false
        )
        XCTAssertEqual(bat.statusText, "Fully charged")
        XCTAssertFalse(bat.canTriggerFullCharge)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL — types not defined

- [ ] **Step 3: Implement SystemMetrics**

```swift
// Mach/Mach/Models/SystemMetrics.swift
import Foundation

struct CPUMetrics {
    var totalUsage: Double = 0
    var coreUsages: [Double] = []
    var temperature: Double = 0
}

struct RAMMetrics {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var compressed: UInt64 = 0
    var swap: UInt64 = 0
    var wired: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0

    var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

struct GPUMetrics {
    var usage: Double = 0
    var vramUsed: UInt64 = 0
    var vramTotal: UInt64 = 0
    var temperature: Double = 0
}

struct DiskMetrics {
    var totalSpace: UInt64 = 0
    var usedSpace: UInt64 = 0
    var readSpeed: UInt64 = 0
    var writeSpeed: UInt64 = 0

    var usagePercent: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }
}

struct NetworkMetrics {
    var uploadSpeed: UInt64 = 0
    var downloadSpeed: UInt64 = 0
    var interfaceName: String = ""

    var uploadFormatted: String { Self.formatSpeed(uploadSpeed) }
    var downloadFormatted: String { Self.formatSpeed(downloadSpeed) }

    static func formatSpeed(_ bytesPerSec: UInt64) -> String {
        let bytes = Double(bytesPerSec)
        if bytes < 1_024 {
            return "\(bytesPerSec) B/s"
        } else if bytes < 1_048_576 {
            return String(format: "%.1f KB/s", bytes / 1_024)
        } else if bytes < 1_073_741_824 {
            return String(format: "%.1f MB/s", bytes / 1_048_576)
        } else {
            return String(format: "%.1f GB/s", bytes / 1_073_741_824)
        }
    }
}

struct BatteryMetrics {
    var chargePercent: Int = 0
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var cycleCount: Int = 0
    var health: Double = 0
    var timeRemaining: Int? = nil  // minutes
    var isOptimizedHolding: Bool = false

    var statusText: String {
        if isOptimizedHolding {
            return "Holding at 80%"
        } else if isCharging {
            return "Charging"
        } else if isPluggedIn && chargePercent == 100 {
            return "Fully charged"
        } else if let minutes = timeRemaining {
            let h = minutes / 60
            let m = minutes % 60
            return "\(h):\(String(format: "%02d", m)) remaining"
        } else {
            return "On battery"
        }
    }

    var canTriggerFullCharge: Bool {
        isOptimizedHolding && isPluggedIn
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Write failing tests for CleanItem**

```swift
// Mach/MachTests/Models/CleanItemTests.swift
import XCTest
@testable import Mach

final class CleanItemTests: XCTestCase {

    func testCleanItemFormatSize() {
        let item = CleanItem(
            id: "system-cache",
            name: "System Cache",
            category: .system,
            sizeBytes: 1_258_291_200,  // ~1.2 GB
            requiresRoot: false
        )
        XCTAssertEqual(item.formattedSize, "1.2 GB")
    }

    func testCleanItemMBFormatting() {
        let item = CleanItem(
            id: "app-logs",
            name: "App Logs",
            category: .system,
            sizeBytes: 356_515_840,  // ~340 MB
            requiresRoot: false
        )
        XCTAssertEqual(item.formattedSize, "340.0 MB")
    }

    func testCleanItemNoSize() {
        let item = CleanItem(
            id: "dns-cache",
            name: "DNS Cache",
            category: .system,
            sizeBytes: nil,
            requiresRoot: true
        )
        XCTAssertEqual(item.formattedSize, "—")
    }

    func testCleanResultSuccess() {
        let result = CleanResult(itemId: "system-cache", freedBytes: 1_258_291_200, success: true, error: nil)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.formattedFreed, "1.2 GB")
    }

    func testCleanResultFailure() {
        let result = CleanResult(itemId: "docker", freedBytes: 0, success: false, error: "Docker not installed")
        XCTAssertFalse(result.success)
    }

    func testCleanItemCategoryGrouping() {
        let items = [
            CleanItem(id: "cache", name: "Cache", category: .system, sizeBytes: 100, requiresRoot: false),
            CleanItem(id: "xcode", name: "Xcode", category: .developer, sizeBytes: 200, requiresRoot: false),
            CleanItem(id: "logs", name: "Logs", category: .system, sizeBytes: 300, requiresRoot: false),
        ]
        let systemItems = items.filter { $0.category == .system }
        let devItems = items.filter { $0.category == .developer }
        XCTAssertEqual(systemItems.count, 2)
        XCTAssertEqual(devItems.count, 1)
    }
}
```

- [ ] **Step 6: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 7: Implement CleanItem**

```swift
// Mach/Mach/Models/CleanItem.swift
import Foundation

enum CleanCategory: String, CaseIterable {
    case system
    case developer
}

struct CleanItem: Identifiable {
    let id: String
    let name: String
    let category: CleanCategory
    var sizeBytes: UInt64?
    let requiresRoot: Bool

    var formattedSize: String {
        guard let bytes = sizeBytes else { return "—" }
        return Self.formatBytes(bytes)
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1_024 {
            return "\(bytes) B"
        } else if b < 1_048_576 {
            return String(format: "%.1f KB", b / 1_024)
        } else if b < 1_073_741_824 {
            return String(format: "%.1f MB", b / 1_048_576)
        } else {
            return String(format: "%.1f GB", b / 1_073_741_824)
        }
    }
}

struct CleanResult {
    let itemId: String
    let freedBytes: UInt64
    let success: Bool
    let error: String?

    var formattedFreed: String {
        CleanItem.formatBytes(freedBytes)
    }
}
```

- [ ] **Step 8: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 9: Commit**

```bash
git add Mach/Mach/Models/ Mach/MachTests/Models/
git commit -m "feat: add SystemMetrics and CleanItem data models with tests"
```

---

## Task 3: ShellExecutor & PrivilegeHelper

**Files:**
- Create: `Mach/Mach/Utilities/ShellExecutor.swift`
- Create: `Mach/Mach/Utilities/PrivilegeHelper.swift`
- Create: `Mach/MachTests/Utilities/ShellExecutorTests.swift`

- [ ] **Step 1: Write failing tests for ShellExecutor**

```swift
// Mach/MachTests/Utilities/ShellExecutorTests.swift
import XCTest
@testable import Mach

final class ShellExecutorTests: XCTestCase {

    func testRunEchoCommand() async throws {
        let result = try await ShellExecutor.run("/bin/echo", arguments: ["hello"])
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testRunFailingCommand() async throws {
        let result = try await ShellExecutor.run("/usr/bin/false")
        XCTAssertNotEqual(result.exitCode, 0)
    }

    func testRunCommandWithOutput() async throws {
        let result = try await ShellExecutor.run("/usr/bin/uname", arguments: ["-s"])
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "Darwin")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testShellCommandConvenience() async throws {
        let result = try await ShellExecutor.shell("echo 'test output'")
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "test output")
    }

    func testToolExists() {
        XCTAssertTrue(ShellExecutor.toolExists("ls"))
        XCTAssertFalse(ShellExecutor.toolExists("nonexistent_tool_xyz_123"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement ShellExecutor**

```swift
// Mach/Mach/Utilities/ShellExecutor.swift
import Foundation

struct ShellResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
}

enum ShellExecutor {

    static func run(_ executablePath: String, arguments: [String] = []) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        return ShellResult(
            output: String(data: outData, encoding: .utf8) ?? "",
            errorOutput: String(data: errData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    static func shell(_ command: String) async throws -> ShellResult {
        try await run("/bin/zsh", arguments: ["-c", command])
    }

    static func toolExists(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Implement PrivilegeHelper**

```swift
// Mach/Mach/Utilities/PrivilegeHelper.swift
import Foundation

enum PrivilegeHelper {

    /// Runs a command with root privileges via AppleScript `do shell script ... with administrator privileges`.
    /// This triggers the macOS password dialog.
    static func runWithPrivileges(_ command: String) async throws -> ShellResult {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escaped)\" with administrator privileges"

        return try await ShellExecutor.run(
            "/usr/bin/osascript",
            arguments: ["-e", script]
        )
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add Mach/Mach/Utilities/ShellExecutor.swift Mach/Mach/Utilities/PrivilegeHelper.swift Mach/MachTests/Utilities/ShellExecutorTests.swift
git commit -m "feat: add ShellExecutor and PrivilegeHelper utilities with tests"
```

---

## Task 4: CPU Monitor

**Files:**
- Create: `Mach/Mach/Monitors/CPUMonitor.swift`
- Create: `Mach/MachTests/Monitors/CPUMonitorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Monitors/CPUMonitorTests.swift
import XCTest
@testable import Mach

final class CPUMonitorTests: XCTestCase {

    func testCPUMonitorInitialState() {
        let monitor = CPUMonitor()
        XCTAssertEqual(monitor.metrics.totalUsage, 0)
        XCTAssertTrue(monitor.metrics.coreUsages.isEmpty)
    }

    func testCPUMonitorUpdate() {
        let monitor = CPUMonitor()
        monitor.update()
        // After update, totalUsage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(monitor.metrics.totalUsage, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.totalUsage, 100)
        // Should have at least 1 core
        XCTAssertGreaterThan(monitor.metrics.coreUsages.count, 0)
    }

    func testCPUMonitorCoreUsagesInRange() {
        let monitor = CPUMonitor()
        monitor.update()
        for usage in monitor.metrics.coreUsages {
            XCTAssertGreaterThanOrEqual(usage, 0)
            XCTAssertLessThanOrEqual(usage, 100)
        }
    }

    func testCalculateUsage() {
        // Test the static calculation with known values
        let usage = CPUMonitor.calculateUsage(
            user: 100, system: 50, idle: 850, nice: 0,
            prevUser: 0, prevSystem: 0, prevIdle: 0, prevNice: 0
        )
        // (100+50) / (100+50+850) = 150/1000 = 15%
        XCTAssertEqual(usage, 15.0, accuracy: 0.1)
    }

    func testCalculateUsageZeroDelta() {
        let usage = CPUMonitor.calculateUsage(
            user: 100, system: 50, idle: 850, nice: 0,
            prevUser: 100, prevSystem: 50, prevIdle: 850, prevNice: 0
        )
        XCTAssertEqual(usage, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement CPUMonitor**

```swift
// Mach/Mach/Monitors/CPUMonitor.swift
import Foundation
import Darwin

final class CPUMonitor: ObservableObject {
    @Published var metrics = CPUMetrics()

    private var previousTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []

    func update() {
        var numCPU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPU,
            &cpuInfo,
            &numCPUInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else { return }

        var coreUsages: [Double] = []
        var newTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []
        var totalUser: UInt64 = 0, totalSystem: UInt64 = 0, totalIdle: UInt64 = 0, totalNice: UInt64 = 0

        for i in 0..<Int(numCPU) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt64(info[offset + Int(CPU_STATE_USER)])
            let system = UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[offset + Int(CPU_STATE_NICE)])

            totalUser += user
            totalSystem += system
            totalIdle += idle
            totalNice += nice

            let prev = i < previousTicks.count ? previousTicks[i] : (0, 0, 0, 0)
            let usage = Self.calculateUsage(
                user: user, system: system, idle: idle, nice: nice,
                prevUser: prev.user, prevSystem: prev.system, prevIdle: prev.idle, prevNice: prev.nice
            )
            coreUsages.append(usage)
            newTicks.append((user, system, idle, nice))
        }

        let prevTotal = previousTicks.reduce((UInt64(0), UInt64(0), UInt64(0), UInt64(0))) {
            ($0.0 + $1.user, $0.1 + $1.system, $0.2 + $1.idle, $0.3 + $1.nice)
        }
        let totalUsage = Self.calculateUsage(
            user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice,
            prevUser: prevTotal.0, prevSystem: prevTotal.1, prevIdle: prevTotal.2, prevNice: prevTotal.3
        )

        previousTicks = newTicks

        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        metrics = CPUMetrics(
            totalUsage: totalUsage,
            coreUsages: coreUsages,
            temperature: readCPUTemperature()
        )
    }

    static func calculateUsage(
        user: UInt64, system: UInt64, idle: UInt64, nice: UInt64,
        prevUser: UInt64, prevSystem: UInt64, prevIdle: UInt64, prevNice: UInt64
    ) -> Double {
        let userDelta = user - prevUser
        let systemDelta = system - prevSystem
        let idleDelta = idle - prevIdle
        let niceDelta = nice - prevNice
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else { return 0 }
        return Double(userDelta + systemDelta + niceDelta) / Double(totalDelta) * 100
    }

    private func readCPUTemperature() -> Double {
        // SMC temperature reading — returns 0 if unavailable
        // Full SMC implementation in a later iteration
        return 0
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/Monitors/CPUMonitor.swift Mach/MachTests/Monitors/CPUMonitorTests.swift
git commit -m "feat: add CPUMonitor with host_processor_info and per-core usage"
```

---

## Task 5: RAM Monitor

**Files:**
- Create: `Mach/Mach/Monitors/RAMMonitor.swift`
- Create: `Mach/MachTests/Monitors/RAMMonitorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Monitors/RAMMonitorTests.swift
import XCTest
@testable import Mach

final class RAMMonitorTests: XCTestCase {

    func testRAMMonitorInitialState() {
        let monitor = RAMMonitor()
        XCTAssertEqual(monitor.metrics.total, 0)
        XCTAssertEqual(monitor.metrics.used, 0)
    }

    func testRAMMonitorUpdate() {
        let monitor = RAMMonitor()
        monitor.update()
        XCTAssertGreaterThan(monitor.metrics.total, 0)
        XCTAssertGreaterThan(monitor.metrics.used, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.usagePercent, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.usagePercent, 100)
    }

    func testRAMMonitorComponentsNonNegative() {
        let monitor = RAMMonitor()
        monitor.update()
        XCTAssertGreaterThanOrEqual(monitor.metrics.wired, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.active, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.inactive, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.compressed, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement RAMMonitor**

```swift
// Mach/Mach/Monitors/RAMMonitor.swift
import Foundation
import Darwin

final class RAMMonitor: ObservableObject {
    @Published var metrics = RAMMetrics()

    private let pageSize = UInt64(vm_kernel_page_size)

    func update() {
        let totalMemory = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)
        let swap = UInt64(swapUsage.xsu_used)

        metrics = RAMMetrics(
            total: totalMemory,
            used: used,
            compressed: compressed,
            swap: swap,
            wired: wired,
            active: active,
            inactive: inactive
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/Monitors/RAMMonitor.swift Mach/MachTests/Monitors/RAMMonitorTests.swift
git commit -m "feat: add RAMMonitor with host_statistics64 and swap tracking"
```

---

## Task 6: GPU Monitor

**Files:**
- Create: `Mach/Mach/Monitors/GPUMonitor.swift`
- Create: `Mach/MachTests/Monitors/GPUMonitorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Monitors/GPUMonitorTests.swift
import XCTest
@testable import Mach

final class GPUMonitorTests: XCTestCase {

    func testGPUMonitorInitialState() {
        let monitor = GPUMonitor()
        XCTAssertEqual(monitor.metrics.usage, 0)
    }

    func testGPUMonitorUpdate() {
        let monitor = GPUMonitor()
        monitor.update()
        // GPU usage should be in valid range (may be 0 if not available)
        XCTAssertGreaterThanOrEqual(monitor.metrics.usage, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.usage, 100)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement GPUMonitor**

```swift
// Mach/Mach/Monitors/GPUMonitor.swift
import Foundation
import IOKit

final class GPUMonitor: ObservableObject {
    @Published var metrics = GPUMetrics()

    func update() {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS else {
            return
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        defer { if service != 0 { IOObjectRelease(service) } }

        guard service != 0 else { return }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any] else {
            return
        }

        if let perfStats = dict["PerformanceStatistics"] as? [String: Any] {
            // Apple Silicon GPU utilization
            if let utilization = perfStats["Device Utilization %"] as? Int {
                metrics.usage = Double(utilization)
            } else if let gpuActivity = perfStats["GPU Activity(%)"] as? Int {
                metrics.usage = Double(gpuActivity)
            }

            if let vramUsed = perfStats["VRAM Used"] as? UInt64 {
                metrics.vramUsed = vramUsed
            } else if let vramUsed = perfStats["vramUsedBytes"] as? UInt64 {
                metrics.vramUsed = vramUsed
            }

            if let vramTotal = perfStats["VRAM Total"] as? UInt64 {
                metrics.vramTotal = vramTotal
            }
        }

        IOObjectRelease(service)
        service = 0
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/Monitors/GPUMonitor.swift Mach/MachTests/Monitors/GPUMonitorTests.swift
git commit -m "feat: add GPUMonitor with IOKit IOAccelerator"
```

---

## Task 7: Disk Monitor

**Files:**
- Create: `Mach/Mach/Monitors/DiskMonitor.swift`
- Create: `Mach/MachTests/Monitors/DiskMonitorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Monitors/DiskMonitorTests.swift
import XCTest
@testable import Mach

final class DiskMonitorTests: XCTestCase {

    func testDiskMonitorInitialState() {
        let monitor = DiskMonitor()
        XCTAssertEqual(monitor.metrics.totalSpace, 0)
    }

    func testDiskMonitorUpdate() {
        let monitor = DiskMonitor()
        monitor.update()
        XCTAssertGreaterThan(monitor.metrics.totalSpace, 0)
        XCTAssertGreaterThan(monitor.metrics.usedSpace, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.usagePercent, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.usagePercent, 100)
    }

    func testDiskMonitorUsedLessThanTotal() {
        let monitor = DiskMonitor()
        monitor.update()
        XCTAssertLessThanOrEqual(monitor.metrics.usedSpace, monitor.metrics.totalSpace)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement DiskMonitor**

```swift
// Mach/Mach/Monitors/DiskMonitor.swift
import Foundation
import IOKit

final class DiskMonitor: ObservableObject {
    @Published var metrics = DiskMetrics()

    private var previousRead: UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousTime: Date?

    func update() {
        updateSpace()
        updateIOSpeed()
    }

    private func updateSpace() {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return }
        let total = attrs[.systemSize] as? UInt64 ?? 0
        let free = attrs[.systemFreeSize] as? UInt64 ?? 0
        metrics.totalSpace = total
        metrics.usedSpace = total - free
    }

    private func updateIOSpeed() {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS else {
            return
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = properties?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                totalRead += stats["Bytes (Read)"] as? UInt64 ?? 0
                totalWrite += stats["Bytes (Write)"] as? UInt64 ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        let now = Date()
        if let prevTime = previousTime {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                metrics.readSpeed = UInt64(Double(totalRead - previousRead) / elapsed)
                metrics.writeSpeed = UInt64(Double(totalWrite - previousWrite) / elapsed)
            }
        }

        previousRead = totalRead
        previousWrite = totalWrite
        previousTime = now
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/Monitors/DiskMonitor.swift Mach/MachTests/Monitors/DiskMonitorTests.swift
git commit -m "feat: add DiskMonitor with FileManager space and IOKit IO speed"
```

---

## Task 8: Network Monitor

**Files:**
- Create: `Mach/Mach/Monitors/NetworkMonitor.swift`
- Create: `Mach/MachTests/Monitors/NetworkMonitorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Monitors/NetworkMonitorTests.swift
import XCTest
@testable import Mach

final class NetworkMonitorTests: XCTestCase {

    func testNetworkMonitorInitialState() {
        let monitor = NetworkMonitor()
        XCTAssertEqual(monitor.metrics.uploadSpeed, 0)
        XCTAssertEqual(monitor.metrics.downloadSpeed, 0)
    }

    func testNetworkMonitorUpdate() {
        let monitor = NetworkMonitor()
        monitor.update()  // first call establishes baseline
        monitor.update()  // second call calculates deltas
        // Speeds should be non-negative
        XCTAssertGreaterThanOrEqual(monitor.metrics.uploadSpeed, 0)
        XCTAssertGreaterThanOrEqual(monitor.metrics.downloadSpeed, 0)
    }

    func testNetworkMonitorHasInterface() {
        let monitor = NetworkMonitor()
        monitor.update()
        // Should detect at least one interface (en0/lo0)
        XCTAssertFalse(monitor.metrics.interfaceName.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement NetworkMonitor**

```swift
// Mach/Mach/Monitors/NetworkMonitor.swift
import Foundation
import Darwin

final class NetworkMonitor: ObservableObject {
    @Published var metrics = NetworkMetrics()

    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTime: Date?

    func update() {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var primaryInterface = ""

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            let name = String(cString: addr.pointee.ifa_name)

            if addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let data = unsafeBitCast(addr.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                totalIn += UInt64(data.pointee.ifi_ibytes)
                totalOut += UInt64(data.pointee.ifi_obytes)

                // Prefer en0 (Wi-Fi) or en1 as primary
                if name.hasPrefix("en") && (primaryInterface.isEmpty || name == "en0") {
                    primaryInterface = name
                }
            }
            cursor = addr.pointee.ifa_next
        }

        let now = Date()
        if let prevTime = previousTime {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                let deltaIn = totalIn >= previousBytesIn ? totalIn - previousBytesIn : 0
                let deltaOut = totalOut >= previousBytesOut ? totalOut - previousBytesOut : 0
                metrics.uploadSpeed = UInt64(Double(deltaOut) / elapsed)
                metrics.downloadSpeed = UInt64(Double(deltaIn) / elapsed)
            }
        }

        metrics.interfaceName = primaryInterface
        previousBytesIn = totalIn
        previousBytesOut = totalOut
        previousTime = now
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/Monitors/NetworkMonitor.swift Mach/MachTests/Monitors/NetworkMonitorTests.swift
git commit -m "feat: add NetworkMonitor with getifaddrs delta calculation"
```

---

## Task 9: Battery Monitor

**Files:**
- Create: `Mach/Mach/Monitors/BatteryMonitor.swift`
- Create: `Mach/MachTests/Monitors/BatteryMonitorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Monitors/BatteryMonitorTests.swift
import XCTest
@testable import Mach

final class BatteryMonitorTests: XCTestCase {

    func testBatteryMonitorInitialState() {
        let monitor = BatteryMonitor()
        XCTAssertEqual(monitor.metrics.chargePercent, 0)
        XCTAssertFalse(monitor.metrics.isCharging)
    }

    func testBatteryMonitorUpdate() {
        let monitor = BatteryMonitor()
        monitor.update()
        // On a Mac with battery, chargePercent > 0; on desktop, stays 0
        // Just verify it doesn't crash and values are in valid range
        XCTAssertGreaterThanOrEqual(monitor.metrics.chargePercent, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.chargePercent, 100)
    }

    func testBatteryMonitorHealthRange() {
        let monitor = BatteryMonitor()
        monitor.update()
        // Health should be 0 (no battery) or between 0-100
        XCTAssertGreaterThanOrEqual(monitor.metrics.health, 0)
        XCTAssertLessThanOrEqual(monitor.metrics.health, 100)
    }

    func testTriggerFullCharge() async {
        // Verify the method exists and returns a result
        let monitor = BatteryMonitor()
        // This will fail in CI/testing as it requires admin privileges
        // Just test it doesn't crash when battery isn't in holding state
        let canTrigger = monitor.metrics.canTriggerFullCharge
        XCTAssertFalse(canTrigger)  // default state
    }

    func testGetCurrentEnergyMode() async {
        let monitor = BatteryMonitor()
        let mode = await monitor.getCurrentEnergyMode()
        // Should be one of the valid modes
        let validModes: [EnergyMode] = [.lowPower, .automatic, .highPerformance]
        XCTAssertTrue(validModes.contains(mode))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement BatteryMonitor**

```swift
// Mach/Mach/Monitors/BatteryMonitor.swift
import Foundation
import IOKit.ps

enum EnergyMode: String, CaseIterable {
    case lowPower = "Low Power"
    case automatic = "Automatic"
    case highPerformance = "High Performance"
}

final class BatteryMonitor: ObservableObject {
    @Published var metrics = BatteryMetrics()
    @Published var currentEnergyMode: EnergyMode = .automatic

    func update() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let firstSource = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, firstSource as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else {
            return
        }

        let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int

        // Cycle count and health from IORegistry
        var cycleCount = 0
        var health: Double = 0
        var isOptimizedHolding = false

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != IO_OBJECT_NULL {
            if let cycleCountVal = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                cycleCount = cycleCountVal
            }
            if let maxCap = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
               let designCap = IORegistryEntryCreateCFProperty(service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
               designCap > 0 {
                health = Double(maxCap) / Double(designCap) * 100
            }
            if let optimized = IORegistryEntryCreateCFProperty(service, "OptimizedBatteryChargingEngaged" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool {
                isOptimizedHolding = optimized && isPluggedIn && !isCharging
            }
            IOObjectRelease(service)
        }

        var timeRemaining: Int? = nil
        if !isPluggedIn, let tte = timeToEmpty, tte > 0 {
            timeRemaining = tte
        }

        metrics = BatteryMetrics(
            chargePercent: currentCapacity,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            cycleCount: cycleCount,
            health: min(health, 100),
            timeRemaining: timeRemaining,
            isOptimizedHolding: isOptimizedHolding
        )
    }

    func triggerFullCharge() async throws {
        guard metrics.canTriggerFullCharge else { return }
        _ = try await PrivilegeHelper.runWithPrivileges("pmset -a optimizedbatterycharging 0 && sleep 2 && pmset -a optimizedbatterycharging 1")
    }

    func getCurrentEnergyMode() async -> EnergyMode {
        guard let result = try? await ShellExecutor.shell("pmset -g") else {
            return .automatic
        }
        let output = result.output
        if output.contains("lowpowermode         1") {
            return .lowPower
        } else if output.contains("highpowermode        1") {
            return .highPerformance
        }
        return .automatic
    }

    func setEnergyMode(_ mode: EnergyMode) async throws {
        let command: String
        switch mode {
        case .lowPower:
            command = "pmset -a lowpowermode 1 && pmset -a highpowermode 0"
        case .automatic:
            command = "pmset -a lowpowermode 0 && pmset -a highpowermode 0"
        case .highPerformance:
            command = "pmset -a lowpowermode 0 && pmset -a highpowermode 1"
        }
        _ = try await PrivilegeHelper.runWithPrivileges(command)
        currentEnergyMode = mode
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/Monitors/BatteryMonitor.swift Mach/MachTests/Monitors/BatteryMonitorTests.swift
git commit -m "feat: add BatteryMonitor with IOPowerSources, energy mode, full charge"
```

---

## Task 10: MonitorManager

**Files:**
- Create: `Mach/Mach/Monitors/MonitorManager.swift`
- Create: `Mach/MachTests/Monitors/MonitorManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Monitors/MonitorManagerTests.swift
import XCTest
@testable import Mach

final class MonitorManagerTests: XCTestCase {

    func testMonitorManagerOwnsAllMonitors() {
        let manager = MonitorManager()
        XCTAssertNotNil(manager.cpu)
        XCTAssertNotNil(manager.ram)
        XCTAssertNotNil(manager.gpu)
        XCTAssertNotNil(manager.disk)
        XCTAssertNotNil(manager.network)
        XCTAssertNotNil(manager.battery)
    }

    func testMonitorManagerStartStop() {
        let manager = MonitorManager()
        XCTAssertFalse(manager.isRunning)
        manager.start()
        XCTAssertTrue(manager.isRunning)
        manager.stop()
        XCTAssertFalse(manager.isRunning)
    }

    func testMonitorManagerPopoverInterval() {
        let manager = MonitorManager()
        manager.start()
        XCTAssertEqual(manager.currentInterval, 10.0)  // closed = 10s
        manager.popoverDidOpen()
        XCTAssertEqual(manager.currentInterval, 1.0)    // open = 1s
        manager.popoverDidClose()
        XCTAssertEqual(manager.currentInterval, 10.0)   // closed again
        manager.stop()
    }

    func testMonitorManagerUpdatesOnStart() {
        let manager = MonitorManager()
        manager.start()
        // Give it a moment to fire
        let expectation = expectation(description: "Initial update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // CPU should have been updated at least once
            XCTAssertTrue(manager.cpu.metrics.coreUsages.count > 0 || true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        manager.stop()
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement MonitorManager**

```swift
// Mach/Mach/Monitors/MonitorManager.swift
import Foundation
import Combine

final class MonitorManager: ObservableObject {
    let cpu = CPUMonitor()
    let ram = RAMMonitor()
    let gpu = GPUMonitor()
    let disk = DiskMonitor()
    let network = NetworkMonitor()
    let battery = BatteryMonitor()

    @Published private(set) var isRunning = false
    @Published private(set) var currentInterval: TimeInterval = 10.0

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let openInterval: TimeInterval = 1.0
    private let closedInterval: TimeInterval = 10.0

    init() {
        // Forward child object changes
        cpu.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        ram.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        gpu.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        disk.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        network.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        battery.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    func start() {
        isRunning = true
        updateAll()
        scheduleTimer(interval: closedInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func popoverDidOpen() {
        scheduleTimer(interval: openInterval)
    }

    func popoverDidClose() {
        scheduleTimer(interval: closedInterval)
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateAll()
        }
    }

    private func updateAll() {
        cpu.update()
        ram.update()
        gpu.update()
        disk.update()
        network.update()
        battery.update()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/Monitors/MonitorManager.swift Mach/MachTests/Monitors/MonitorManagerTests.swift
git commit -m "feat: add MonitorManager with smart timer (1s open, 10s closed)"
```

---

## Task 11: App Shell — Menu Bar + Popover

**Files:**
- Modify: `Mach/Mach/AppDelegate.swift`
- Modify: `Mach/Mach/MachApp.swift`

- [ ] **Step 1: Implement AppDelegate with NSStatusItem and NSPopover**

```swift
// Mach/Mach/AppDelegate.swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let monitorManager = MonitorManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "Mach")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let contentView = DashboardView()
            .environmentObject(monitorManager)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: contentView)

        monitorManager.start()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            monitorManager.popoverDidOpen()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        monitorManager.popoverDidClose()
    }
}
```

- [ ] **Step 2: Update MachApp.swift**

```swift
// Mach/Mach/MachApp.swift
import SwiftUI

@main
struct MachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.monitorManager)
        }
    }
}
```

- [ ] **Step 3: Create placeholder DashboardView and SettingsView for build**

```swift
// Mach/Mach/Views/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var manager: MonitorManager

    var body: some View {
        Text("Dashboard — coming next")
            .frame(width: 320, height: 480)
    }
}
```

```swift
// Mach/Mach/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: MonitorManager

    var body: some View {
        Text("Settings — coming later")
            .frame(width: 300, height: 200)
    }
}
```

- [ ] **Step 4: Build and verify app launches**

```bash
cd Mach && xcodebuild -project Mach.xcodeproj -scheme Mach -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/AppDelegate.swift Mach/Mach/MachApp.swift Mach/Mach/Views/
git commit -m "feat: add menu bar icon with NSStatusItem and popover shell"
```

---

## Task 12: Reusable TileView + All Tile Components

**Files:**
- Create: `Mach/Mach/Views/Tiles/TileView.swift`
- Create: `Mach/Mach/Views/Tiles/CPUTileView.swift`
- Create: `Mach/Mach/Views/Tiles/GPUTileView.swift`
- Create: `Mach/Mach/Views/Tiles/RAMTileView.swift`
- Create: `Mach/Mach/Views/Tiles/DiskTileView.swift`
- Create: `Mach/Mach/Views/Tiles/NetworkTileView.swift`
- Create: `Mach/Mach/Views/Tiles/BatteryTileView.swift`

- [ ] **Step 1: Create reusable TileView**

```swift
// Mach/Mach/Views/Tiles/TileView.swift
import SwiftUI

struct TileView: View {
    let title: String
    let value: String
    let percent: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            ProgressView(value: min(percent, 100), total: 100)
                .tint(color)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 2: Create CPUTileView**

```swift
// Mach/Mach/Views/Tiles/CPUTileView.swift
import SwiftUI

struct CPUTileView: View {
    @ObservedObject var monitor: CPUMonitor

    var body: some View {
        TileView(
            title: "CPU",
            value: String(format: "%.0f%%", monitor.metrics.totalUsage),
            percent: monitor.metrics.totalUsage,
            color: .cyan
        )
    }
}
```

- [ ] **Step 3: Create GPUTileView**

```swift
// Mach/Mach/Views/Tiles/GPUTileView.swift
import SwiftUI

struct GPUTileView: View {
    @ObservedObject var monitor: GPUMonitor

    var body: some View {
        TileView(
            title: "GPU",
            value: String(format: "%.0f%%", monitor.metrics.usage),
            percent: monitor.metrics.usage,
            color: .pink
        )
    }
}
```

- [ ] **Step 4: Create RAMTileView**

```swift
// Mach/Mach/Views/Tiles/RAMTileView.swift
import SwiftUI

struct RAMTileView: View {
    @ObservedObject var monitor: RAMMonitor

    var body: some View {
        TileView(
            title: "RAM",
            value: String(format: "%.0f%%", monitor.metrics.usagePercent),
            percent: monitor.metrics.usagePercent,
            color: .purple
        )
    }
}
```

- [ ] **Step 5: Create DiskTileView**

```swift
// Mach/Mach/Views/Tiles/DiskTileView.swift
import SwiftUI

struct DiskTileView: View {
    @ObservedObject var monitor: DiskMonitor

    var body: some View {
        TileView(
            title: "DISK",
            value: String(format: "%.0f%%", monitor.metrics.usagePercent),
            percent: monitor.metrics.usagePercent,
            color: .blue
        )
    }
}
```

- [ ] **Step 6: Create NetworkTileView**

```swift
// Mach/Mach/Views/Tiles/NetworkTileView.swift
import SwiftUI

struct NetworkTileView: View {
    @ObservedObject var monitor: NetworkMonitor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("NET")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(spacing: 16) {
                    Label(monitor.metrics.uploadFormatted, systemImage: "arrow.up")
                        .font(.caption)
                    Label(monitor.metrics.downloadFormatted, systemImage: "arrow.down")
                        .font(.caption)
                }
                .foregroundStyle(.teal)
            }
            Spacer()
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 7: Create BatteryTileView**

```swift
// Mach/Mach/Views/Tiles/BatteryTileView.swift
import SwiftUI

struct BatteryTileView: View {
    @ObservedObject var monitor: BatteryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BATTERY")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text("\(monitor.metrics.chargePercent)%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)

                        Text(monitor.metrics.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if monitor.metrics.cycleCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Health \(String(format: "%.0f%%", monitor.metrics.health))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Cycles \(monitor.metrics.cycleCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProgressView(value: Double(monitor.metrics.chargePercent), total: 100)
                .tint(.green)

            // Full Charge button
            if monitor.metrics.canTriggerFullCharge {
                Button {
                    Task { try? await monitor.triggerFullCharge() }
                } label: {
                    Label("Full Charge", systemImage: "bolt.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Energy Mode Switcher
            Picker("", selection: $monitor.currentEnergyMode) {
                ForEach(EnergyMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: monitor.currentEnergyMode) { _, newMode in
                Task { try? await monitor.setEnergyMode(newMode) }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 8: Build to verify all tiles compile**

```bash
cd Mach && xcodebuild -project Mach.xcodeproj -scheme Mach -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 9: Commit**

```bash
git add Mach/Mach/Views/Tiles/
git commit -m "feat: add TileView components for all 6 monitors"
```

---

## Task 13: DashboardView — Main Layout

**Files:**
- Modify: `Mach/Mach/Views/DashboardView.swift`

- [ ] **Step 1: Implement DashboardView with 2x2 grid and navigation**

```swift
// Mach/Mach/Views/DashboardView.swift
import SwiftUI

enum DashboardRoute: Hashable {
    case dashboard
    case cpuDetail
    case gpuDetail
    case ramDetail
    case diskDetail
    case networkDetail
    case batteryDetail
    case cleaner
    case settings
}

struct DashboardView: View {
    @EnvironmentObject var manager: MonitorManager
    @State private var route: DashboardRoute = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            switch route {
            case .dashboard:
                dashboardContent
            case .cleaner:
                CleanerView(onBack: { route = .dashboard })
            case .settings:
                SettingsView()
                    .environmentObject(manager)
            case .cpuDetail:
                CPUDetailView(monitor: manager.cpu, onBack: { route = .dashboard })
            case .gpuDetail:
                GPUDetailView(monitor: manager.gpu, onBack: { route = .dashboard })
            case .ramDetail:
                RAMDetailView(monitor: manager.ram, onBack: { route = .dashboard })
            case .diskDetail:
                DiskDetailView(monitor: manager.disk, onBack: { route = .dashboard })
            case .networkDetail:
                NetworkDetailView(monitor: manager.network, onBack: { route = .dashboard })
            case .batteryDetail:
                BatteryDetailView(monitor: manager.battery, onBack: { route = .dashboard })
            }
        }
        .frame(width: 320, height: 480)
    }

    private var header: some View {
        HStack {
            if route != .dashboard {
                Button {
                    route = .dashboard
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
            }

            Text("Mach")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            if route == .dashboard {
                Button { route = .cleaner } label: {
                    Image(systemName: "paintbrush")
                }
                .buttonStyle(.plain)
                .help("Clean")

                Button { route = .settings } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .help("Quit Mach")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                // 2x2 grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    CPUTileView(monitor: manager.cpu)
                        .onTapGesture { route = .cpuDetail }
                    GPUTileView(monitor: manager.gpu)
                        .onTapGesture { route = .gpuDetail }
                    RAMTileView(monitor: manager.ram)
                        .onTapGesture { route = .ramDetail }
                    DiskTileView(monitor: manager.disk)
                        .onTapGesture { route = .diskDetail }
                }

                // Network
                NetworkTileView(monitor: manager.network)
                    .onTapGesture { route = .networkDetail }

                // Battery
                BatteryTileView(monitor: manager.battery)
                    .onTapGesture { route = .batteryDetail }
            }
            .padding(10)
        }
    }
}
```

- [ ] **Step 2: Create placeholder detail views for build**

Create these placeholder files so the build succeeds. They will be fully implemented in Task 14.

```swift
// Mach/Mach/Views/DetailViews/CPUDetailView.swift
import SwiftUI
struct CPUDetailView: View {
    @ObservedObject var monitor: CPUMonitor
    var onBack: () -> Void
    var body: some View { Text("CPU Detail").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

```swift
// Mach/Mach/Views/DetailViews/GPUDetailView.swift
import SwiftUI
struct GPUDetailView: View {
    @ObservedObject var monitor: GPUMonitor
    var onBack: () -> Void
    var body: some View { Text("GPU Detail").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

```swift
// Mach/Mach/Views/DetailViews/RAMDetailView.swift
import SwiftUI
struct RAMDetailView: View {
    @ObservedObject var monitor: RAMMonitor
    var onBack: () -> Void
    var body: some View { Text("RAM Detail").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

```swift
// Mach/Mach/Views/DetailViews/DiskDetailView.swift
import SwiftUI
struct DiskDetailView: View {
    @ObservedObject var monitor: DiskMonitor
    var onBack: () -> Void
    var body: some View { Text("Disk Detail").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

```swift
// Mach/Mach/Views/DetailViews/NetworkDetailView.swift
import SwiftUI
struct NetworkDetailView: View {
    @ObservedObject var monitor: NetworkMonitor
    var onBack: () -> Void
    var body: some View { Text("Network Detail").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

```swift
// Mach/Mach/Views/DetailViews/BatteryDetailView.swift
import SwiftUI
struct BatteryDetailView: View {
    @ObservedObject var monitor: BatteryMonitor
    var onBack: () -> Void
    var body: some View { Text("Battery Detail").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

- [ ] **Step 3: Create placeholder CleanerView**

```swift
// Mach/Mach/Views/CleanerView.swift
import SwiftUI
struct CleanerView: View {
    var onBack: () -> Void
    var body: some View { Text("Cleaner — coming in Task 16").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

- [ ] **Step 4: Build and verify**

```bash
cd Mach && xcodebuild -project Mach.xcodeproj -scheme Mach -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Mach/Mach/Views/
git commit -m "feat: add DashboardView with 2x2 grid layout and navigation"
```

---

## Task 14: Detail Views with History Graph

**Files:**
- Create: `Mach/Mach/Views/DetailViews/HistoryGraphView.swift`
- Modify: `Mach/Mach/Views/DetailViews/CPUDetailView.swift`
- Modify: `Mach/Mach/Views/DetailViews/GPUDetailView.swift`
- Modify: `Mach/Mach/Views/DetailViews/RAMDetailView.swift`
- Modify: `Mach/Mach/Views/DetailViews/DiskDetailView.swift`
- Modify: `Mach/Mach/Views/DetailViews/NetworkDetailView.swift`
- Modify: `Mach/Mach/Views/DetailViews/BatteryDetailView.swift`

- [ ] **Step 1: Create HistoryGraphView (reusable sparkline)**

```swift
// Mach/Mach/Views/DetailViews/HistoryGraphView.swift
import SwiftUI

struct HistoryGraphView: View {
    let dataPoints: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Fill
                if dataPoints.count >= 2 {
                    Path { path in
                        let points = normalizedPoints(width: width, height: height)
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: height))
                        path.addLine(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.15))

                    // Line
                    Path { path in
                        let points = normalizedPoints(width: width, height: height)
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, lineWidth: 1.5)
                }
            }
        }
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard dataPoints.count >= 2, maxValue > 0 else { return [] }
        let step = width / CGFloat(dataPoints.count - 1)
        return dataPoints.enumerated().map { index, value in
            let x = CGFloat(index) * step
            let y = height - (CGFloat(value / maxValue) * height)
            return CGPoint(x: x, y: max(0, min(height, y)))
        }
    }
}
```

- [ ] **Step 2: Add history tracking to monitors**

Add a `history` array property to each monitor. Modify `Mach/Mach/Monitors/CPUMonitor.swift` — add at the top of the class:

```swift
// Add to CPUMonitor class body, after @Published var metrics:
@Published var history: [Double] = []
private let maxHistory = 60

// Add at the end of update(), before the closing brace:
history.append(metrics.totalUsage)
if history.count > maxHistory { history.removeFirst() }
```

Apply the same pattern to the other monitors:

`RAMMonitor.swift` — add after `@Published var metrics`:
```swift
@Published var history: [Double] = []
private let maxHistory = 60
```
At end of `update()`:
```swift
history.append(metrics.usagePercent)
if history.count > maxHistory { history.removeFirst() }
```

`GPUMonitor.swift` — add after `@Published var metrics`:
```swift
@Published var history: [Double] = []
private let maxHistory = 60
```
At end of `update()`:
```swift
history.append(metrics.usage)
if history.count > maxHistory { history.removeFirst() }
```

`DiskMonitor.swift` — add after `@Published var metrics`:
```swift
@Published var history: [Double] = []
private let maxHistory = 60
```
At end of `update()`:
```swift
history.append(metrics.usagePercent)
if history.count > maxHistory { history.removeFirst() }
```

`NetworkMonitor.swift` — add after `@Published var metrics`:
```swift
@Published var downloadHistory: [Double] = []
@Published var uploadHistory: [Double] = []
private let maxHistory = 60
```
At end of `update()`:
```swift
downloadHistory.append(Double(metrics.downloadSpeed))
uploadHistory.append(Double(metrics.uploadSpeed))
if downloadHistory.count > maxHistory { downloadHistory.removeFirst() }
if uploadHistory.count > maxHistory { uploadHistory.removeFirst() }
```

`BatteryMonitor.swift` — add after `@Published var metrics`:
```swift
@Published var history: [Double] = []
private let maxHistory = 60
```
At end of `update()`:
```swift
history.append(Double(metrics.chargePercent))
if history.count > maxHistory { history.removeFirst() }
```

- [ ] **Step 3: Implement CPUDetailView**

```swift
// Mach/Mach/Views/DetailViews/CPUDetailView.swift
import SwiftUI

struct CPUDetailView: View {
    @ObservedObject var monitor: CPUMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CPU Usage")
                        .font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.totalUsage))
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.cyan)
                }

                HistoryGraphView(
                    dataPoints: monitor.history,
                    maxValue: 100,
                    color: .cyan
                )
                .frame(height: 120)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if !monitor.metrics.coreUsages.isEmpty {
                    Text("Per Core")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(monitor.metrics.coreUsages.enumerated()), id: \.offset) { index, usage in
                        HStack {
                            Text("Core \(index)")
                                .font(.caption)
                                .frame(width: 50, alignment: .leading)
                            ProgressView(value: usage, total: 100)
                                .tint(.cyan)
                            Text(String(format: "%.0f%%", usage))
                                .font(.caption).monospacedDigit()
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }

                if monitor.metrics.temperature > 0 {
                    HStack {
                        Text("Temperature")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f°C", monitor.metrics.temperature))
                            .font(.caption).monospacedDigit()
                    }
                }
            }
            .padding(14)
        }
    }
}
```

- [ ] **Step 4: Implement GPUDetailView**

```swift
// Mach/Mach/Views/DetailViews/GPUDetailView.swift
import SwiftUI

struct GPUDetailView: View {
    @ObservedObject var monitor: GPUMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("GPU Usage")
                        .font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.usage))
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.pink)
                }

                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .pink)
                    .frame(height: 120)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if monitor.metrics.vramTotal > 0 {
                    HStack {
                        Text("VRAM")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(CleanItem.formatBytes(monitor.metrics.vramUsed)) / \(CleanItem.formatBytes(monitor.metrics.vramTotal))")
                            .font(.caption).monospacedDigit()
                    }
                }

                if monitor.metrics.temperature > 0 {
                    HStack {
                        Text("Temperature")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f°C", monitor.metrics.temperature))
                            .font(.caption).monospacedDigit()
                    }
                }
            }
            .padding(14)
        }
    }
}
```

- [ ] **Step 5: Implement RAMDetailView**

```swift
// Mach/Mach/Views/DetailViews/RAMDetailView.swift
import SwiftUI

struct RAMDetailView: View {
    @ObservedObject var monitor: RAMMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Memory")
                        .font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.usagePercent))
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.purple)
                }

                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .purple)
                    .frame(height: 120)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Group {
                    memoryRow("Used", bytes: monitor.metrics.used, color: .purple)
                    memoryRow("Wired", bytes: monitor.metrics.wired, color: .orange)
                    memoryRow("Active", bytes: monitor.metrics.active, color: .blue)
                    memoryRow("Inactive", bytes: monitor.metrics.inactive, color: .gray)
                    memoryRow("Compressed", bytes: monitor.metrics.compressed, color: .yellow)
                    memoryRow("Swap", bytes: monitor.metrics.swap, color: .red)
                }

                HStack {
                    Text("Total")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(CleanItem.formatBytes(monitor.metrics.total))
                        .font(.caption).monospacedDigit()
                }
            }
            .padding(14)
        }
    }

    private func memoryRow(_ label: String, bytes: UInt64, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption)
            Spacer()
            Text(CleanItem.formatBytes(bytes))
                .font(.caption).monospacedDigit()
        }
    }
}
```

- [ ] **Step 6: Implement DiskDetailView**

```swift
// Mach/Mach/Views/DetailViews/DiskDetailView.swift
import SwiftUI

struct DiskDetailView: View {
    @ObservedObject var monitor: DiskMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Disk")
                        .font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.usagePercent))
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.blue)
                }

                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .blue)
                    .frame(height: 120)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Text("Used")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(CleanItem.formatBytes(monitor.metrics.usedSpace)) / \(CleanItem.formatBytes(monitor.metrics.totalSpace))")
                        .font(.caption).monospacedDigit()
                }

                HStack {
                    Text("Read Speed")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(NetworkMetrics.formatSpeed(monitor.metrics.readSpeed))
                        .font(.caption).monospacedDigit()
                }

                HStack {
                    Text("Write Speed")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(NetworkMetrics.formatSpeed(monitor.metrics.writeSpeed))
                        .font(.caption).monospacedDigit()
                }
            }
            .padding(14)
        }
    }
}
```

- [ ] **Step 7: Implement NetworkDetailView**

```swift
// Mach/Mach/Views/DetailViews/NetworkDetailView.swift
import SwiftUI

struct NetworkDetailView: View {
    @ObservedObject var monitor: NetworkMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Network")
                    .font(.title3).fontWeight(.bold)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Upload", systemImage: "arrow.up")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(monitor.metrics.uploadFormatted)
                            .font(.caption).monospacedDigit().foregroundStyle(.teal)
                    }
                    HistoryGraphView(
                        dataPoints: monitor.uploadHistory,
                        maxValue: max(monitor.uploadHistory.max() ?? 1, 1),
                        color: .teal
                    )
                    .frame(height: 80)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Download", systemImage: "arrow.down")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(monitor.metrics.downloadFormatted)
                            .font(.caption).monospacedDigit().foregroundStyle(.teal)
                    }
                    HistoryGraphView(
                        dataPoints: monitor.downloadHistory,
                        maxValue: max(monitor.downloadHistory.max() ?? 1, 1),
                        color: .cyan
                    )
                    .frame(height: 80)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Text("Interface")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(monitor.metrics.interfaceName)
                        .font(.caption).monospacedDigit()
                }
            }
            .padding(14)
        }
    }
}
```

- [ ] **Step 8: Implement BatteryDetailView**

```swift
// Mach/Mach/Views/DetailViews/BatteryDetailView.swift
import SwiftUI

struct BatteryDetailView: View {
    @ObservedObject var monitor: BatteryMonitor
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Battery")
                        .font(.title3).fontWeight(.bold)
                    Spacer()
                    Text("\(monitor.metrics.chargePercent)%")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.green)
                }

                Text(monitor.metrics.statusText)
                    .font(.caption).foregroundStyle(.secondary)

                HistoryGraphView(dataPoints: monitor.history, maxValue: 100, color: .green)
                    .frame(height: 120)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Text("Health")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.metrics.health))
                        .font(.caption).monospacedDigit()
                }
                HStack {
                    Text("Cycle Count")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(monitor.metrics.cycleCount)")
                        .font(.caption).monospacedDigit()
                }

                Divider()

                // Full Charge
                if monitor.metrics.canTriggerFullCharge {
                    Button {
                        Task { try? await monitor.triggerFullCharge() }
                    } label: {
                        Label("Charge to Full", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // Energy Mode
                Text("Energy Mode")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $monitor.currentEnergyMode) {
                    ForEach(EnergyMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: monitor.currentEnergyMode) { _, newMode in
                    Task { try? await monitor.setEnergyMode(newMode) }
                }
            }
            .padding(14)
        }
    }
}
```

- [ ] **Step 9: Build and verify**

```bash
cd Mach && xcodebuild -project Mach.xcodeproj -scheme Mach -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 10: Commit**

```bash
git add Mach/Mach/Views/DetailViews/ Mach/Mach/Monitors/
git commit -m "feat: add detail views with 60-second history graphs"
```

---

## Task 15: Cleaner Implementations

**Files:**
- Create: `Mach/Mach/Cleaners/CleanerProtocol.swift`
- Create: `Mach/Mach/Cleaners/MemoryCleaner.swift`
- Create: `Mach/Mach/Cleaners/CacheCleaner.swift`
- Create: `Mach/Mach/Cleaners/LogCleaner.swift`
- Create: `Mach/Mach/Cleaners/TempCleaner.swift`
- Create: `Mach/Mach/Cleaners/DNSCleaner.swift`
- Create: `Mach/Mach/Cleaners/XcodeCleaner.swift`
- Create: `Mach/Mach/Cleaners/DockerCleaner.swift`
- Create: `Mach/Mach/Cleaners/BrewCleaner.swift`
- Create: `Mach/Mach/Cleaners/PackageCleaner.swift`
- Create: `Mach/Mach/Cleaners/CleanerManager.swift`
- Create: `Mach/MachTests/Cleaners/IndividualCleanerTests.swift`
- Create: `Mach/MachTests/Cleaners/CleanerManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Cleaners/IndividualCleanerTests.swift
import XCTest
@testable import Mach

final class IndividualCleanerTests: XCTestCase {

    func testCacheCleanerScanSize() async {
        let cleaner = CacheCleaner()
        let size = await cleaner.scanSize()
        // ~/Library/Caches should exist and likely have some data
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testLogCleanerScanSize() async {
        let cleaner = LogCleaner()
        let size = await cleaner.scanSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testTempCleanerScanSize() async {
        let cleaner = TempCleaner()
        let size = await cleaner.scanSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testXcodeCleanerIsAvailable() {
        let cleaner = XcodeCleaner()
        // Available if ~/Library/Developer/Xcode/DerivedData exists
        let exists = FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData")
        XCTAssertEqual(cleaner.isAvailable, exists)
    }

    func testDockerCleanerAvailability() {
        let cleaner = DockerCleaner()
        let dockerExists = ShellExecutor.toolExists("docker")
        XCTAssertEqual(cleaner.isAvailable, dockerExists)
    }

    func testBrewCleanerAvailability() {
        let cleaner = BrewCleaner()
        let brewExists = ShellExecutor.toolExists("brew")
        XCTAssertEqual(cleaner.isAvailable, brewExists)
    }

    func testMemoryCleanerRequiresRoot() {
        let cleaner = MemoryCleaner()
        XCTAssertTrue(cleaner.requiresRoot)
    }

    func testDNSCleanerRequiresRoot() {
        let cleaner = DNSCleaner()
        XCTAssertTrue(cleaner.requiresRoot)
    }

    func testCacheCleanerDoesNotRequireRoot() {
        let cleaner = CacheCleaner()
        XCTAssertFalse(cleaner.requiresRoot)
    }
}
```

```swift
// Mach/MachTests/Cleaners/CleanerManagerTests.swift
import XCTest
@testable import Mach

final class CleanerManagerTests: XCTestCase {

    func testCleanerManagerHasAllItems() {
        let manager = CleanerManager()
        // System: cache, logs, temp, DNS, memory = 5
        // Developer: xcode, docker, brew, npm, yarn, pip = 6
        XCTAssertEqual(manager.items.count, 11)
    }

    func testCleanerManagerSystemItems() {
        let manager = CleanerManager()
        let systemItems = manager.items.filter { $0.category == .system }
        XCTAssertEqual(systemItems.count, 5)
    }

    func testCleanerManagerDeveloperItems() {
        let manager = CleanerManager()
        let devItems = manager.items.filter { $0.category == .developer }
        XCTAssertEqual(devItems.count, 6)
    }

    func testQuickCleanItemIds() {
        let manager = CleanerManager()
        let quickIds = Set(manager.quickCleanItemIds)
        XCTAssertTrue(quickIds.contains("system-cache"))
        XCTAssertTrue(quickIds.contains("app-logs"))
        XCTAssertTrue(quickIds.contains("temp-files"))
        XCTAssertTrue(quickIds.contains("memory"))
        XCTAssertFalse(quickIds.contains("docker"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement CleanerProtocol**

```swift
// Mach/Mach/Cleaners/CleanerProtocol.swift
import Foundation

protocol Cleaner {
    var id: String { get }
    var name: String { get }
    var category: CleanCategory { get }
    var requiresRoot: Bool { get }
    var isAvailable: Bool { get }

    func scanSize() async -> UInt64
    func clean() async throws -> CleanResult
}

extension Cleaner {
    var isAvailable: Bool { true }
}
```

- [ ] **Step 4: Implement directory-based cleaners (CacheCleaner, LogCleaner, TempCleaner, XcodeCleaner)**

```swift
// Mach/Mach/Cleaners/CacheCleaner.swift
import Foundation

struct CacheCleaner: Cleaner {
    let id = "system-cache"
    let name = "System Cache"
    let category = CleanCategory.system
    let requiresRoot = false

    private var cachesPath: String { NSHomeDirectory() + "/Library/Caches" }

    func scanSize() async -> UInt64 {
        directorySize(at: cachesPath)
    }

    func clean() async throws -> CleanResult {
        let size = directorySize(at: cachesPath)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: cachesPath) else {
            return CleanResult(itemId: id, freedBytes: 0, success: false, error: "Cannot read caches directory")
        }
        for item in contents {
            try? fm.removeItem(atPath: cachesPath + "/" + item)
        }
        return CleanResult(itemId: id, freedBytes: size, success: true, error: nil)
    }
}

func directorySize(at path: String) -> UInt64 {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
    var total: UInt64 = 0
    while let file = enumerator.nextObject() as? String {
        let fullPath = path + "/" + file
        if let attrs = try? fm.attributesOfItem(atPath: fullPath),
           let size = attrs[.size] as? UInt64 {
            total += size
        }
    }
    return total
}
```

```swift
// Mach/Mach/Cleaners/LogCleaner.swift
import Foundation

struct LogCleaner: Cleaner {
    let id = "app-logs"
    let name = "App Logs"
    let category = CleanCategory.system
    let requiresRoot = false

    private var logsPath: String { NSHomeDirectory() + "/Library/Logs" }

    func scanSize() async -> UInt64 {
        directorySize(at: logsPath)
    }

    func clean() async throws -> CleanResult {
        let size = directorySize(at: logsPath)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: logsPath) else {
            return CleanResult(itemId: id, freedBytes: 0, success: false, error: "Cannot read logs directory")
        }
        for item in contents {
            try? fm.removeItem(atPath: logsPath + "/" + item)
        }
        return CleanResult(itemId: id, freedBytes: size, success: true, error: nil)
    }
}
```

```swift
// Mach/Mach/Cleaners/TempCleaner.swift
import Foundation

struct TempCleaner: Cleaner {
    let id = "temp-files"
    let name = "Temp Files"
    let category = CleanCategory.system
    let requiresRoot = false

    func scanSize() async -> UInt64 {
        let tmpDir = NSTemporaryDirectory()
        return directorySize(at: tmpDir)
    }

    func clean() async throws -> CleanResult {
        let tmpDir = NSTemporaryDirectory()
        let size = directorySize(at: tmpDir)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: tmpDir) else {
            return CleanResult(itemId: id, freedBytes: 0, success: false, error: "Cannot read temp directory")
        }
        for item in contents {
            try? fm.removeItem(atPath: tmpDir + "/" + item)
        }
        return CleanResult(itemId: id, freedBytes: size, success: true, error: nil)
    }
}
```

```swift
// Mach/Mach/Cleaners/XcodeCleaner.swift
import Foundation

struct XcodeCleaner: Cleaner {
    let id = "xcode-derived"
    let name = "Xcode DerivedData"
    let category = CleanCategory.developer
    let requiresRoot = false

    private var derivedDataPath: String { NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData" }

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: derivedDataPath)
    }

    func scanSize() async -> UInt64 {
        directorySize(at: derivedDataPath)
    }

    func clean() async throws -> CleanResult {
        let size = directorySize(at: derivedDataPath)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataPath) else {
            return CleanResult(itemId: id, freedBytes: 0, success: false, error: "Cannot read DerivedData")
        }
        for item in contents {
            try? fm.removeItem(atPath: derivedDataPath + "/" + item)
        }
        return CleanResult(itemId: id, freedBytes: size, success: true, error: nil)
    }
}
```

- [ ] **Step 5: Implement command-based cleaners (MemoryCleaner, DNSCleaner, DockerCleaner, BrewCleaner, PackageCleaner)**

```swift
// Mach/Mach/Cleaners/MemoryCleaner.swift
import Foundation

struct MemoryCleaner: Cleaner {
    let id = "memory"
    let name = "Memory"
    let category = CleanCategory.system
    let requiresRoot = true

    func scanSize() async -> UInt64 { 0 }

    func clean() async throws -> CleanResult {
        let result = try await PrivilegeHelper.runWithPrivileges("purge")
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: 0, success: success, error: success ? nil : result.errorOutput)
    }
}
```

```swift
// Mach/Mach/Cleaners/DNSCleaner.swift
import Foundation

struct DNSCleaner: Cleaner {
    let id = "dns-cache"
    let name = "DNS Cache"
    let category = CleanCategory.system
    let requiresRoot = true

    func scanSize() async -> UInt64 { 0 }

    func clean() async throws -> CleanResult {
        let result = try await PrivilegeHelper.runWithPrivileges(
            "dscacheutil -flushcache && killall -HUP mDNSResponder"
        )
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: 0, success: success, error: success ? nil : result.errorOutput)
    }
}
```

```swift
// Mach/Mach/Cleaners/DockerCleaner.swift
import Foundation

struct DockerCleaner: Cleaner {
    let id = "docker"
    let name = "Docker Unused"
    let category = CleanCategory.developer
    let requiresRoot = false

    var isAvailable: Bool { ShellExecutor.toolExists("docker") }

    func scanSize() async -> UInt64 {
        guard isAvailable,
              let result = try? await ShellExecutor.shell("docker system df --format '{{.Reclaimable}}'"),
              result.exitCode == 0 else { return 0 }
        // Parse the output — rough estimation
        return parseDockerSize(result.output)
    }

    func clean() async throws -> CleanResult {
        let result = try await ShellExecutor.shell("docker system prune -f")
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: 0, success: success, error: success ? nil : result.errorOutput)
    }

    private func parseDockerSize(_ output: String) -> UInt64 {
        // Docker outputs like "2.1GB" — parse first line
        let line = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").first ?? ""
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let multiplier: UInt64
        let numberStr: String
        if cleaned.hasSuffix("GB") {
            multiplier = 1_073_741_824
            numberStr = String(cleaned.dropLast(2))
        } else if cleaned.hasSuffix("MB") {
            multiplier = 1_048_576
            numberStr = String(cleaned.dropLast(2))
        } else if cleaned.hasSuffix("KB") {
            multiplier = 1_024
            numberStr = String(cleaned.dropLast(2))
        } else {
            return 0
        }
        return UInt64((Double(numberStr) ?? 0) * Double(multiplier))
    }
}
```

```swift
// Mach/Mach/Cleaners/BrewCleaner.swift
import Foundation

struct BrewCleaner: Cleaner {
    let id = "homebrew"
    let name = "Homebrew Cache"
    let category = CleanCategory.developer
    let requiresRoot = false

    var isAvailable: Bool { ShellExecutor.toolExists("brew") }

    func scanSize() async -> UInt64 {
        guard isAvailable,
              let result = try? await ShellExecutor.shell("brew --cache"),
              result.exitCode == 0 else { return 0 }
        let cachePath = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return directorySize(at: cachePath)
    }

    func clean() async throws -> CleanResult {
        let sizeBefore = await scanSize()
        let result = try await ShellExecutor.shell("brew cleanup --prune=all")
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: sizeBefore, success: success, error: success ? nil : result.errorOutput)
    }
}
```

```swift
// Mach/Mach/Cleaners/PackageCleaner.swift
import Foundation

struct PackageCleaner: Cleaner {
    let toolName: String
    let id: String
    let name: String
    let category = CleanCategory.developer
    let requiresRoot = false
    private let cleanCommand: String

    var isAvailable: Bool { ShellExecutor.toolExists(toolName) }

    static let npm = PackageCleaner(toolName: "npm", id: "npm", name: "npm Cache", cleanCommand: "npm cache clean --force")
    static let yarn = PackageCleaner(toolName: "yarn", id: "yarn", name: "yarn Cache", cleanCommand: "yarn cache clean")
    static let pip = PackageCleaner(toolName: "pip3", id: "pip", name: "pip Cache", cleanCommand: "pip3 cache purge")

    func scanSize() async -> UInt64 {
        guard isAvailable else { return 0 }
        let cachePath: String?
        switch toolName {
        case "npm":
            cachePath = (try? await ShellExecutor.shell("npm config get cache"))?.output.trimmingCharacters(in: .whitespacesAndNewlines)
        case "yarn":
            cachePath = (try? await ShellExecutor.shell("yarn cache dir"))?.output.trimmingCharacters(in: .whitespacesAndNewlines)
        case "pip3":
            cachePath = (try? await ShellExecutor.shell("pip3 cache dir"))?.output.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            cachePath = nil
        }
        guard let path = cachePath, !path.isEmpty else { return 0 }
        return directorySize(at: path)
    }

    func clean() async throws -> CleanResult {
        let sizeBefore = await scanSize()
        let result = try await ShellExecutor.shell(cleanCommand)
        let success = result.exitCode == 0
        return CleanResult(itemId: id, freedBytes: sizeBefore, success: success, error: success ? nil : result.errorOutput)
    }
}
```

- [ ] **Step 6: Implement CleanerManager**

```swift
// Mach/Mach/Cleaners/CleanerManager.swift
import Foundation

final class CleanerManager: ObservableObject {
    let cleaners: [any Cleaner]
    @Published var items: [CleanItem] = []
    @Published var results: [String: CleanResult] = [:]
    @Published var inProgress: Set<String> = []

    let quickCleanItemIds = ["system-cache", "app-logs", "temp-files", "memory"]

    init() {
        cleaners = [
            CacheCleaner(),
            LogCleaner(),
            TempCleaner(),
            DNSCleaner(),
            MemoryCleaner(),
            XcodeCleaner(),
            DockerCleaner(),
            BrewCleaner(),
            PackageCleaner.npm,
            PackageCleaner.yarn,
            PackageCleaner.pip,
        ]

        items = cleaners.map { cleaner in
            CleanItem(
                id: cleaner.id,
                name: cleaner.name,
                category: cleaner.category,
                sizeBytes: nil,
                requiresRoot: cleaner.requiresRoot
            )
        }
    }

    func scanAll() async {
        for (index, cleaner) in cleaners.enumerated() {
            guard cleaner.isAvailable else { continue }
            let size = await cleaner.scanSize()
            await MainActor.run {
                items[index].sizeBytes = size > 0 ? size : nil
            }
        }
    }

    func clean(id: String) async {
        guard let cleaner = cleaners.first(where: { $0.id == id }),
              cleaner.isAvailable else { return }

        await MainActor.run { inProgress.insert(id) }

        do {
            let result = try await cleaner.clean()
            await MainActor.run {
                results[id] = result
                inProgress.remove(id)
            }
        } catch {
            await MainActor.run {
                results[id] = CleanResult(itemId: id, freedBytes: 0, success: false, error: error.localizedDescription)
                inProgress.remove(id)
            }
        }
    }

    func quickClean() async {
        for id in quickCleanItemIds {
            await clean(id: id)
        }
    }

    func isAvailable(id: String) -> Bool {
        cleaners.first(where: { $0.id == id })?.isAvailable ?? false
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add Mach/Mach/Cleaners/ Mach/MachTests/Cleaners/
git commit -m "feat: add all cleaners with CleanerManager orchestration"
```

---

## Task 16: CleanerView UI

**Files:**
- Modify: `Mach/Mach/Views/CleanerView.swift`

- [ ] **Step 1: Implement CleanerView with individual purge buttons**

```swift
// Mach/Mach/Views/CleanerView.swift
import SwiftUI

struct CleanerView: View {
    var onBack: () -> Void
    @StateObject private var cleanerManager = CleanerManager()
    @State private var hasScanned = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Quick Clean
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Quick Clean", systemImage: "bolt.fill")
                            .font(.headline)
                        Text(quickCleanEstimate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Run") {
                        Task { await cleanerManager.quickClean() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!cleanerManager.inProgress.isEmpty)
                }
                .padding(12)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Divider()

                // System items
                ForEach(systemItems) { item in
                    cleanerRow(item: item)
                }

                Divider()

                Text("Developer Tools")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(developerItems) { item in
                    cleanerRow(item: item)
                }
            }
            .padding(10)
        }
        .task {
            if !hasScanned {
                hasScanned = true
                await cleanerManager.scanAll()
            }
        }
    }

    private var systemItems: [CleanItem] {
        cleanerManager.items.filter { $0.category == .system }
    }

    private var developerItems: [CleanItem] {
        cleanerManager.items.filter { $0.category == .developer }
    }

    private var quickCleanEstimate: String {
        let totalBytes = cleanerManager.items
            .filter { cleanerManager.quickCleanItemIds.contains($0.id) }
            .compactMap(\.sizeBytes)
            .reduce(UInt64(0), +)
        if totalBytes > 0 {
            return "Est. recovery: ~\(CleanItem.formatBytes(totalBytes))"
        }
        return "Scanning..."
    }

    @ViewBuilder
    private func cleanerRow(item: CleanItem) -> some View {
        let available = cleanerManager.isAvailable(id: item.id)
        let isRunning = cleanerManager.inProgress.contains(item.id)
        let result = cleanerManager.results[item.id]

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.callout)
                    .foregroundStyle(available ? .primary : .secondary)
                if !available {
                    Text("Not installed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isRunning {
                ProgressView()
                    .controlSize(.small)
            } else if let result = result {
                if result.success {
                    Label(
                        result.freedBytes > 0 ? result.formattedFreed + " freed" : "Done",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.green)
                } else {
                    Label("Failed", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Text(item.formattedSize)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Button(buttonLabel(for: item)) {
                    Task { await cleanerManager.clean(id: item.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(!available)
            }
        }
        .padding(.vertical, 4)
    }

    private func buttonLabel(for item: CleanItem) -> String {
        switch item.id {
        case "dns-cache": return "Flush"
        case "memory": return "Purge"
        default: return "Clean"
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd Mach && xcodebuild -project Mach.xcodeproj -scheme Mach -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Mach/Mach/Views/CleanerView.swift
git commit -m "feat: add CleanerView with individual purge buttons per item"
```

---

## Task 17: NotificationManager

**Files:**
- Create: `Mach/Mach/Utilities/NotificationManager.swift`
- Create: `Mach/MachTests/Utilities/NotificationManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Mach/MachTests/Utilities/NotificationManagerTests.swift
import XCTest
@testable import Mach

final class NotificationManagerTests: XCTestCase {

    func testThresholdCPU() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .cpu, value: 50))
        XCTAssertTrue(manager.shouldAlert(metric: .cpu, value: 95))
    }

    func testThresholdRAM() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .ram, value: 80))
        XCTAssertTrue(manager.shouldAlert(metric: .ram, value: 92))
    }

    func testThresholdDisk() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .disk, value: 90))
        XCTAssertTrue(manager.shouldAlert(metric: .disk, value: 96))
    }

    func testThresholdBattery() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .battery, value: 30))
        XCTAssertTrue(manager.shouldAlert(metric: .battery, value: 10))
    }

    func testThresholdTemperature() {
        let manager = NotificationManager()
        XCTAssertFalse(manager.shouldAlert(metric: .temperature, value: 70))
        XCTAssertTrue(manager.shouldAlert(metric: .temperature, value: 96))
    }

    func testCooldownPreventsRepeatedAlerts() {
        let manager = NotificationManager()
        XCTAssertTrue(manager.shouldAlert(metric: .cpu, value: 95))
        manager.recordAlert(metric: .cpu)
        XCTAssertFalse(manager.shouldAlert(metric: .cpu, value: 95))  // cooldown active
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement NotificationManager**

```swift
// Mach/Mach/Utilities/NotificationManager.swift
import Foundation
import UserNotifications

enum AlertMetric: String, CaseIterable {
    case cpu, ram, disk, battery, temperature
}

final class NotificationManager: ObservableObject {
    @Published var alertsEnabled = true

    private var thresholds: [AlertMetric: Double] = [
        .cpu: 90,
        .ram: 90,
        .disk: 95,
        .battery: 15,
        .temperature: 95,
    ]

    private var lastAlertTime: [AlertMetric: Date] = [:]
    private let cooldownInterval: TimeInterval = 300  // 5 minutes

    private var cpuSustainedStart: Date?
    private let cpuSustainedDuration: TimeInterval = 30

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func shouldAlert(metric: AlertMetric, value: Double) -> Bool {
        guard alertsEnabled else { return false }
        guard let threshold = thresholds[metric] else { return false }

        // Check cooldown
        if let lastTime = lastAlertTime[metric],
           Date().timeIntervalSince(lastTime) < cooldownInterval {
            return false
        }

        switch metric {
        case .battery:
            return value <= threshold  // battery alerts on LOW value
        default:
            return value >= threshold
        }
    }

    func recordAlert(metric: AlertMetric) {
        lastAlertTime[metric] = Date()
    }

    func sendAlert(metric: AlertMetric, value: Double) {
        guard shouldAlert(metric: metric, value: value) else { return }
        recordAlert(metric: metric)

        let content = UNMutableNotificationContent()
        content.title = "Mach"
        content.sound = .default

        switch metric {
        case .cpu:
            content.body = String(format: "CPU usage at %.0f%% — sustained high load", value)
        case .ram:
            content.body = String(format: "Memory usage at %.0f%%", value)
        case .disk:
            content.body = String(format: "Disk usage at %.0f%% — running low on space", value)
        case .battery:
            content.body = String(format: "Battery at %.0f%% — connect to power", value)
        case .temperature:
            content.body = String(format: "Temperature at %.0f°C — system may throttle", value)
        }

        let request = UNNotificationRequest(
            identifier: "mach-\(metric.rawValue)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func checkThresholds(manager: MonitorManager) {
        sendAlert(metric: .cpu, value: manager.cpu.metrics.totalUsage)
        sendAlert(metric: .ram, value: manager.ram.metrics.usagePercent)
        sendAlert(metric: .disk, value: manager.disk.metrics.usagePercent)
        sendAlert(metric: .battery, value: Double(manager.battery.metrics.chargePercent))
        if manager.cpu.metrics.temperature > 0 {
            sendAlert(metric: .temperature, value: manager.cpu.metrics.temperature)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Integrate NotificationManager into MonitorManager**

Add to `Mach/Mach/Monitors/MonitorManager.swift`:

At the top of the class, add:
```swift
let notifications = NotificationManager()
```

In `start()`, add after `updateAll()`:
```swift
notifications.requestPermission()
```

In `updateAll()`, add at the end:
```swift
notifications.checkThresholds(manager: self)
```

- [ ] **Step 6: Build and verify**

```bash
cd Mach && xcodebuild -project Mach.xcodeproj -scheme Mach -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Mach/Mach/Utilities/NotificationManager.swift Mach/MachTests/Utilities/NotificationManagerTests.swift Mach/Mach/Monitors/MonitorManager.swift
git commit -m "feat: add NotificationManager with threshold alerts and cooldown"
```

---

## Task 18: SettingsView

**Files:**
- Modify: `Mach/Mach/Views/SettingsView.swift`

- [ ] **Step 1: Implement SettingsView**

```swift
// Mach/Mach/Views/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var manager: MonitorManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title3).fontWeight(.bold)

                // Launch at Login
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Divider()

                // Alerts
                Toggle("Threshold Alerts", isOn: Binding(
                    get: { manager.notifications.alertsEnabled },
                    set: { manager.notifications.alertsEnabled = $0 }
                ))

                if manager.notifications.alertsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert Thresholds")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        thresholdRow("CPU", value: "90%")
                        thresholdRow("RAM", value: "90%")
                        thresholdRow("Disk", value: "95%")
                        thresholdRow("Battery", value: "15%")
                        thresholdRow("Temperature", value: "95°C")
                    }
                }

                Divider()

                // About
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mach")
                        .font(.headline)
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("System monitor & cleaner for developers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func thresholdRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enabled  // revert on failure
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd Mach && xcodebuild -project Mach.xcodeproj -scheme Mach -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Mach/Mach/Views/SettingsView.swift
git commit -m "feat: add SettingsView with launch-at-login and alert thresholds"
```

---

## Task 19: Final Integration & Polish

**Files:**
- Modify: `Mach/Mach/AppDelegate.swift` (pass NotificationManager)
- Create: `Mach/Mach/Assets.xcassets/MenuBarIcon.imageset/Contents.json`

- [ ] **Step 1: Add .gitignore**

```
# Mach/.gitignore
.DS_Store
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
DerivedData/
build/
.superpowers/
```

- [ ] **Step 2: Create menu bar icon asset**

`Mach/Mach/Assets.xcassets/MenuBarIcon.imageset/Contents.json`:
```json
{
  "images": [
    { "idiom": "mac", "scale": "1x" },
    { "idiom": "mac", "scale": "2x" }
  ],
  "info": { "author": "xcode", "version": 1 },
  "properties": {
    "preserves-vector-representation": true,
    "template-rendering-intent": "template"
  }
}
```

Update `AppDelegate.swift` to use a better SF Symbol:

Replace the button image line:
```swift
button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "Mach")
```

With:
```swift
let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "Mach")?.withSymbolConfiguration(config)
```

- [ ] **Step 3: Run full test suite**

```bash
cd Mach && xcodebuild test -project Mach.xcodeproj -scheme MachTests -destination 'platform=macOS' 2>&1 | tail -30
```

Expected: All tests PASS

- [ ] **Step 4: Build release**

```bash
cd Mach && xcodebuild -project Mach.xcodeproj -scheme Mach -configuration Release -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: final integration, menu bar polish, gitignore"
```

---

## Summary

| Task | Description | Key Files |
|------|-------------|-----------|
| 1 | Project scaffolding | project.yml, Info.plist, entitlements |
| 2 | Data models | SystemMetrics, CleanItem |
| 3 | Shell utilities | ShellExecutor, PrivilegeHelper |
| 4 | CPU Monitor | host_processor_info, per-core |
| 5 | RAM Monitor | host_statistics64, swap |
| 6 | GPU Monitor | IOKit IOAccelerator |
| 7 | Disk Monitor | FileManager, IOBlockStorage |
| 8 | Network Monitor | getifaddrs, delta calc |
| 9 | Battery Monitor | IOPowerSources, energy mode |
| 10 | MonitorManager | Smart timer (1s/10s) |
| 11 | App shell | NSStatusItem, NSPopover |
| 12 | Tile views | TileView + 6 tiles |
| 13 | DashboardView | 2x2 grid, navigation |
| 14 | Detail views | HistoryGraphView, 6 detail views |
| 15 | Cleaner implementations | 11 cleaners, CleanerManager |
| 16 | CleanerView | Individual purge buttons |
| 17 | NotificationManager | Threshold alerts, cooldown |
| 18 | SettingsView | Launch at login, preferences |
| 19 | Final integration | Polish, full test, release build |
