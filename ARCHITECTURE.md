# Architecture & System Design: Count Tongula's Eye Break

A technical deep-dive into the system design, architecture, and engineering decisions behind a native macOS menu bar application — built entirely with Claude Code.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Technology Stack & Build System](#technology-stack--build-system)
3. [Application Architecture](#application-architecture)
4. [Timer & Break Scheduling Engine](#timer--break-scheduling-engine)
5. [System Integration Layer](#system-integration-layer)
6. [Multi-Monitor Window Management](#multi-monitor-window-management)
7. [UI Architecture & Theming](#ui-architecture--theming)
8. [Auto-Update Pipeline (Sparkle)](#auto-update-pipeline-sparkle)
9. [Build & Distribution Pipeline](#build--distribution-pipeline)
10. [Performance Engineering](#performance-engineering)
11. [Data Persistence & Statistics](#data-persistence--statistics)
12. [Security Model](#security-model)
13. [Testing & Developer Tooling](#testing--developer-tooling)
14. [Key Design Decisions & Trade-offs](#key-design-decisions--trade-offs)

---

## System Overview

Count Tongula's Eye Break is a persistent macOS menu bar application that implements the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds. It runs as an `LSUIElement` (no Dock icon), lives in the system menu bar, and manages break windows across all connected displays.

The app is structured as a single-binary SwiftPM executable with two runtime dependencies (Lottie for animations, Sparkle for auto-updates), compiled into a universal binary (arm64 + x86_64) and distributed as a signed DMG.

### High-Level Component Map

```
main.swift (entry point, mode routing)
    |
    v
AppDelegate (NSStatusItem, timer loop, break orchestration)
    |
    +-- IdleDetector (IOKit, CGEventSource, DND file polling)
    +-- BreakWindowController (prompt/countdown/complete screens, companion windows)
    +-- Preferences (UserDefaults wrapper with reactive notifications)
    +-- Statistics (JSON-backed daily records, streaks, milestones)
    +-- SoundManager (afplay subprocess for system sounds)
    +-- Theme (Dracula palette, CoreText font registration, custom UI components)
    +-- OnboardingController (first-run configuration flow)
    +-- SettingsWindowController (two-column preference panel)
    +-- StatsChartWindowController (30-day history visualization)
    +-- FeedbackWindowController (bug report / feature request forms)
    +-- SPUStandardUpdaterController (Sparkle auto-update)
```

---

## Technology Stack & Build System

### Why SwiftPM Over Xcode

The app uses a Swift Package Manager executable target with no `.xcodeproj` file. This was a deliberate architectural choice:

- **Single source of truth**: `Package.swift` defines all dependencies, targets, and build settings. No configuration drift between IDE state and build definition.
- **Reproducible CI builds**: The build script runs `swift build -c release --arch arm64` directly — no Xcode version sensitivity or scheme selection.
- **Dependency management via GitHub URLs**: Lottie and Sparkle are declared as SPM packages. No CocoaPods Podfile, no Carthage Cartfile, no additional tooling.

```swift
// Package.swift
let package = Package(
    name: "EyeBreak",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "eye_break_ui",
            dependencies: [
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "scripts/Sources",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
```

The trade-off is that SwiftPM cannot produce universal binaries in a single invocation. The build script compensates by compiling each architecture separately and merging with `lipo` (detailed in [Build & Distribution Pipeline](#build--distribution-pipeline)).

### Runtime Dependencies

| Dependency | Purpose | Integration |
|-----------|---------|-------------|
| **Lottie 4.x** | Vector animations during break countdown | Statically linked via SPM |
| **Sparkle 2.x** | Auto-update (check, download, verify, install, relaunch) | Dynamically linked XCFramework embedded in app bundle |

Sparkle is the only dynamic dependency — it ships as an XCFramework that must be embedded in `Contents/Frameworks/` with an `@rpath` entry so the loader resolves it at runtime.

---

## Application Architecture

### Entry Point & Mode Routing

`main.swift` serves as both the production entry point and a development tool multiplexer. Before constructing the AppDelegate, it routes based on command-line arguments:

```
--demo           → 3-second playthrough of all screens
--screenshot     → Capture eye break cycle to disk
--screenshot-all → Generate all 8 marketing screenshots
--gallery        → Keyboard-navigable screen viewer (arrow keys)
--trigger-eye    → Launch interactive eye break window
--trigger-long   → Launch interactive long break window
(none)           → Normal menu bar app
```

A file-based single-instance guard (`flock` on `/tmp/com.counttongula.eyebreak.lock`) prevents duplicate instances in production mode, while dev modes bypass the lock so multiple instances can coexist during testing.

### Singleton Coordination

The app uses singletons for resources that are inherently unique:

- **`Preferences.shared`** — wraps a single `UserDefaults.standard` store
- **`Statistics.shared`** — owns the single stats JSON file
- **`IdleDetector.shared`** — one set of IOKit/CGEventSource monitors
- **`SoundManager.shared`** — serializes sound playback

Each singleton is stateless in the functional sense — they hold cached state but derive behavior from system queries or persisted data, not from accumulated in-memory mutations.

### Reactive Preferences

Settings changes propagate through `NSNotificationCenter`. When any preference is mutated, the setter calls `notify()`, which posts `Preferences.didChangeNotification`. The AppDelegate observes this and recalculates timer state:

```swift
// Preferences.swift
var breakInterval: Int {
    get { defaults.integer(forKey: Key.breakInterval.rawValue) }
    set { defaults.set(newValue, forKey: Key.breakInterval.rawValue); notify() }
}

// AppDelegate.swift
@objc func preferencesDidChange() {
    let newInterval = Preferences.shared.breakInterval
    if secondsUntilBreak > newInterval {
        secondsUntilBreak = newInterval
        updateStatusDisplay()
    }
}
```

This ensures that if a user reduces their break interval from 30 to 20 minutes and the current countdown is at 25 minutes remaining, it immediately snaps to 20 minutes rather than waiting for the full original interval.

---

## Timer & Break Scheduling Engine

### Main Timer Loop

The core scheduling engine is a 1-second `NSTimer` that decrements a counter and evaluates state on every tick. The `tick()` method implements a priority-ordered state machine:

```
1. Paused?              → Show "Paused", return
2. System sleeping/locked/DND? → Show "Deferred", return
3. User idle?           → Reset timer (natural break), return
4. Excluded app active? → Show "Excluded", return
5. Decrement counter    → Update display
6. Counter <= 0?        → Trigger break
```

Each state check short-circuits via `return`, so only one code path executes per tick. The `lastTickWasSpecial` flag tracks whether the previous tick was in a special state, used to avoid redundant UI updates.

### Break Type Scheduling

Two break types are interleaved:

- **Eye break**: 20 seconds (configurable 5–60s). The standard 20-20-20 break.
- **Long break**: 5 minutes (configurable 1–10min). A stretch/movement break triggered every N eye breaks.

```swift
if prefs.longBreakEnabled && eyeBreaksSinceLastLong >= prefs.longBreakEveryN {
    breakType = .long
    eyeBreaksSinceLastLong = 0
} else {
    breakType = .eye
}
```

The counter `eyeBreaksSinceLastLong` only increments on completed eye breaks — snoozed or skipped breaks don't advance it.

### Snooze & Dismiss Flow

When a break triggers, the user has three options:

1. **Start Break** → Enter countdown mode, timer ticks down the break duration
2. **Snooze** → Dismiss the window, start a separate snooze timer (default 5 min), re-trigger on expiry
3. **Dismiss** → Close the window, restart the interval timer immediately

The snooze timer is independent from the main break timer, with its own 1-second tick that updates the menu bar display ("Snoozed — 4:32"). A `snoozedThisBreak` flag prevents double-snoozing.

---

## System Integration Layer

### Idle Detection Architecture

`IdleDetector` monitors four system signals to determine if breaks should be deferred or reset:

| Signal | Source | Method |
|--------|--------|--------|
| System sleep | `NSWorkspace.willSleepNotification` / `didWakeNotification` | Notification observer |
| Screen lock | `IORegistryEntryCreateCFProperty("IOConsoleLocked")` | IOKit registry query |
| DND / Focus mode | `~/Library/DoNotDisturb/DB/Assertions.json` | File I/O + JSON parse |
| User input idle | `CGEventSource.secondsSinceLastEventType` | WindowServer IPC |

#### Why IOKit for Screen Lock Detection

There is no public AppKit or Foundation API to query whether the screen is locked. The `IOConsoleLocked` key in the IORegistry is the most reliable method:

```swift
private func pollScreenLocked() -> Bool {
    let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/")
    guard entry != 0 else { return false }
    defer { IOObjectRelease(entry) }
    guard let value = IORegistryEntryCreateCFProperty(
        entry, "IOConsoleLocked" as CFString, kCFAllocatorDefault, 0
    )?.takeRetainedValue() as? Bool else { return false }
    return value
}
```

The `defer { IOObjectRelease(entry) }` ensures proper ref-counting — IOKit objects are manually managed, not ARC'd.

#### Why File I/O for DND Detection

macOS stores Focus/DND state in `~/Library/DoNotDisturb/DB/Assertions.json`. There is no public API to query this. The file contains an array of assertion records — if any `storeAssertionRecords` array is non-empty, a Focus mode is active:

```swift
for entry in dataArray {
    if let records = entry["storeAssertionRecords"] as? [Any], !records.isEmpty {
        return true
    }
}
```

This is an undocumented but stable approach used by other macOS menu bar utilities.

#### Background Polling Architecture

All three polling methods (IOKit, file I/O, CGEventSource) involve inter-process communication or disk reads. Running these on the main thread would cause compositor stutter, especially during macOS Space-switching animations.

The solution is a dedicated `DispatchQueue` with `.utility` QoS that polls every 5 seconds with 1-second leeway (allowing the OS scheduler to coalesce with other work for power efficiency):

```swift
private let pollQueue = DispatchQueue(label: "com.counttongula.idledetector", qos: .utility)

private func startBackgroundPolling() {
    let timer = DispatchSource.makeTimerSource(queue: pollQueue)
    timer.schedule(deadline: .now(), repeating: .seconds(5), leeway: .milliseconds(1000))
    timer.setEventHandler { [weak self] in
        self?.cachedIsScreenLocked = self?.pollScreenLocked() ?? false
        self?.cachedIsDNDActive = self?.pollDNDActive() ?? false
        self?.cachedSecondsSinceLastInput = self?.pollSecondsSinceLastInput() ?? 0
    }
}
```

The main thread reads cached values (`cachedIsScreenLocked`, `cachedIsDNDActive`, `cachedSecondsSinceLastInput`) without blocking. The 5-second polling interval means state changes are detected within 5 seconds — acceptable for break deferral where sub-second precision is unnecessary.

### Sleep/Wake Handling

Two distinct behaviors on wake from sleep:

1. **Break window is NOT showing**: `IdleDetector.isSystemSleeping` becomes false, timer resumes from where it was. The `shouldDeferBreak` property was preventing the counter from decrementing during sleep, so no time is "lost."

2. **Break window IS showing**: The `BreakWindowController`'s wake observer auto-dismisses the break as completed, since the user was away and effectively rested:

```swift
wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil, queue: .main
) { [weak self] _ in
    self?.finishWithResult(.completed)
}
```

This prevents stale break windows from lingering after the user returns from an extended absence.

---

## Multi-Monitor Window Management

### Companion Window Architecture

When a break triggers, the app creates windows on every connected display:

1. **Primary window** (460x560): Full break UI with mascot, countdown, buttons, animations
2. **Companion windows** (one per secondary screen): Mirrors the countdown and messages, no interactive buttons

```swift
let mouseLocation = NSEvent.mouseLocation
let targetScreen = NSScreen.screens.first(where: {
    NSMouseInRect(mouseLocation, $0.frame, false)
}) ?? NSScreen.main

// Primary on cursor's screen
window.setFrameOrigin(...)

// Companions on all other screens
for screen in NSScreen.screens where screen.frame != primaryFrame {
    let comp = buildCompanion(on: screen)
    companions.append(comp)
}
```

The primary window is placed on the screen containing the mouse cursor, not necessarily the main display. This respects the user's current focus.

### Window Configuration

All break windows share these properties:

```swift
win.level = .floating                                    // Above normal windows
win.collectionBehavior = [.canJoinAllSpaces,             // Visible on all Spaces
                          .fullScreenAuxiliary]           // Doesn't interfere with fullscreen
win.titlebarAppearsTransparent = true                    // Borderless appearance
win.appearance = NSAppearance(named: .darkAqua)          // Force dark mode
```

The `.canJoinAllSpaces` behavior is critical — without it, a user on Space 2 would miss a break triggered while Space 1 is active.

### Fullscreen Overlay

When `Preferences.shared.fullscreenOverlay` is enabled, semi-transparent overlay windows dim all screens during the break, drawing attention to the break window. These overlay windows are ordered out on dismissal alongside companion windows.

---

## UI Architecture & Theming

### Dracula Theme System

All colors are defined as static `NSColor` instances in `Theme.swift`, matching the exact RGB values from [draculatheme.com](https://draculatheme.com):

```swift
struct Drac {
    static let background  = NSColor(r: 40,  g: 42,  b: 54)   // #282A36
    static let currentLine = NSColor(r: 68,  g: 71,  b: 90)   // #44475A
    static let foreground  = NSColor(r: 248, g: 248, b: 242)   // #F8F8F2
    static let comment     = NSColor(r: 98,  g: 114, b: 164)   // #6272A4
    static let purple      = NSColor(r: 189, g: 147, b: 249)   // #BD93F9
    static let pink        = NSColor(r: 255, g: 121, b: 198)   // #FF79C6
    static let green       = NSColor(r: 80,  g: 250, b: 123)   // #50FA7B
    static let cyan        = NSColor(r: 139, g: 233, b: 253)   // #8BE9FD
    static let orange      = NSColor(r: 255, g: 184, b: 108)   // #FFB86C
    static let red         = NSColor(r: 255, g: 85,  b: 85)    // #FF5555
    static let yellow      = NSColor(r: 241, g: 250, b: 140)   // #F1FA8C
}
```

All windows force `NSAppearance(named: .darkAqua)` to ensure consistent rendering regardless of the user's system appearance setting.

### Custom Font Loading via CoreText

The app bundles DM Sans and DM Mono fonts (from Google Fonts) and registers them at process scope using CoreText:

```swift
func registerCustomFonts() {
    let fontFiles = ["DMSans-Regular.ttf", "DMSans-Medium.ttf", "DMSans-Bold.ttf",
                     "DMMono-Regular.ttf", "DMMono-Medium.ttf"]
    for file in fontFiles {
        let url = URL(fileURLWithPath: assetPath("fonts/\(file)")) as CFURL
        CTFontManagerRegisterFontsForURL(url, .process, nil)
    }
}
```

`.process` scope means fonts are only available to this application — no system-wide side effects. If registration fails (e.g., missing font file), the `dmSans()` and `dmMono()` helper functions fall back to the system font.

### Layout Strategy: Frame-Based vs. Auto Layout

The codebase uses two layout strategies, chosen per window type:

| Window | Layout | Why |
|--------|--------|-----|
| Settings (740x740) | Frame-based | Fixed size, non-resizable, predictable two-column grid |
| Onboarding (500x520) | Frame-based | Fixed size, simple vertical stack |
| Break window (460x560) | Auto Layout | Text wrapping varies with quote length; responsive to content |
| Companion windows | Frame-based | Simple mirror of primary content |

Frame-based layout avoids constraint resolution overhead and is easier to reason about for fixed-size windows. Auto Layout is used only where content-driven sizing is needed (variable-length quotes in the break window).

### Custom UI Components

`Theme.swift` provides three reusable UI components:

- **`HoverButton`**: Layer-backed button with 150ms color animation on hover (`NSAnimationContext`), rounded corners (radius 10), DM Sans Bold 15pt. Used for "Start Break", "Snooze", "Download Update".
- **`HoverLink`**: Text-only link with color transition on mouse enter/exit. Used for "Not now—remind me later", "Skip This Version".
- **`ProgressBarView`**: Custom `NSView` that draws a rounded rectangle track and fill bar, clipped to the track path. Used for break countdown progress.

### Lottie Animation Integration

Break windows display looping vector animations loaded from JSON files:

```swift
let animDir = assetPath("animations")
if let contents = try? FileManager.default.contentsOfDirectory(atPath: animDir) {
    animationFiles = contents.filter { $0.hasSuffix(".json") }
        .map { "\(animDir)/\($0)" }
}
```

A random animation is selected per break from a shuffled pool. The `unusedAnimations` array tracks which animations haven't been shown yet to avoid repeats until all have been cycled.

---

## Auto-Update Pipeline (Sparkle)

### Why Sparkle

Sparkle is the de facto standard for macOS app auto-updates, used by Firefox, VLC, iTerm2, and most indie Mac apps. It handles the full lifecycle:

1. **Check**: Fetch `appcast.xml` (RSS feed) from a configured URL
2. **Compare**: Semantic version comparison against running version
3. **Prompt**: Native macOS update dialog with release notes
4. **Download**: Fetch the DMG from GitHub Releases
5. **Verify**: Validate EdDSA (Ed25519) signature against embedded public key
6. **Install**: Mount DMG, replace app bundle, relaunch

### Integration Architecture

```swift
// AppDelegate.swift — initialization
updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)

// Menu item
@objc func checkForUpdates() {
    updaterController.checkForUpdates(nil)
}
```

`SPUStandardUpdaterController` manages its own UI windows, update check intervals, skip-version preferences, and download progress. The app provides zero custom update UI.

### Appcast & Signing

The `appcast.xml` file is hosted in the repository and served via `raw.githubusercontent.com`:

```xml
<enclosure
    url="https://github.com/alextongme/.../CountTongulasEyeBreak-0.10.0.dmg"
    sparkle:edSignature="Zy7YTIPN0x+..."
    length="11778085"
    type="application/octet-stream"
/>
```

The build script generates this automatically:

1. `sign_update` (Sparkle CLI tool) signs the DMG with the EdDSA private key stored in the macOS Keychain
2. The signature and file size are parsed and injected into `appcast.xml`
3. The public key (`SUPublicEDKey`) is embedded in the app's `Info.plist`

This means a compromised GitHub release (replaced DMG) would fail signature verification — the attacker would need the private key from the developer's Keychain.

### Replacing the Custom Update Checker

Before Sparkle, the app had a hand-rolled update system:

- `UpdateChecker.swift`: Polled GitHub's `/releases/latest` API, compared semver, showed custom alert
- `UpdateAlertController.swift`: Custom Dracula-themed window with "Download Update" button that opened the GitHub release page in a browser

This was replaced entirely by Sparkle. The custom code was deleted — not deprecated, not feature-flagged, deleted. Sparkle handles the same responsibilities with better security (EdDSA verification), better UX (in-app download + install), and zero maintenance burden.

---

## Build & Distribution Pipeline

### Build Flow

```
build-app.sh <version>
    |
    +-- swift build -c release --arch arm64
    +-- swift build -c release --arch x86_64
    |
    +-- lipo -create → universal binary
    |
    +-- Assemble .app bundle
    |   +-- Copy binary to Contents/MacOS/
    |   +-- Embed Sparkle.framework in Contents/Frameworks/
    |   +-- install_name_tool -add_rpath @executable_path/../Frameworks
    |   +-- Copy assets (images, fonts, animations) to Contents/Resources/
    |   +-- Generate Info.plist (version, SUFeedURL, SUPublicEDKey)
    |
    +-- codesign --force --deep --sign -
    |
    +-- ditto → .zip (for Homebrew Cask)
    +-- hdiutil → .dmg (for direct download, with /Applications symlink)
    |
    +-- sign_update → EdDSA signature
    +-- Generate appcast.xml
```

### Universal Binary via lipo

SwiftPM cannot produce universal (fat) binaries natively. The build script works around this:

```bash
swift build -c release --arch arm64 --package-path "$REPO_DIR"
swift build -c release --arch x86_64 --package-path "$REPO_DIR"

lipo -create \
    ".build/arm64-apple-macosx/release/eye_break_ui" \
    ".build/x86_64-apple-macosx/release/eye_break_ui" \
    -output "$BUILD_DIR/eye_break_ui"
```

An earlier approach used `--arch arm64 --arch x86_64` in a single invocation, but this triggered SwiftPM's internal xcodebuild pathway which broke Lottie's `swiftLanguageVersions` configuration. Separate builds avoid this entirely.

### Asset Resolution

The app supports multiple deployment layouts (development, symlink install, DMG, Homebrew). `Theme.swift` resolves asset paths by searching five locations in order:

1. `~/.eye-break/assets/` (legacy symlink layout)
2. Adjacent to binary (repo layout during development)
3. One directory up from binary (repo fallback)
4. Inside `.app` bundle's `Contents/Resources/` (DMG/Homebrew distribution)
5. Current working directory (SPM development)

This multi-path resolution means the same binary works in all deployment scenarios without conditional compilation or environment variables.

---

## Performance Engineering

### Main Thread Protection

The most impactful performance optimization is keeping expensive operations off the main thread. Three specific patterns:

**1. Idle detection polling on background queue** (covered above in System Integration Layer)

**2. Status bar title deduplication**: Setting `NSStatusItem.button.title` triggers a WindowServer redraw. The tick handler guards against redundant updates:

```swift
if let button = statusItem.button, button.title != newTitle {
    button.title = newTitle
}
```

This reduces compositor redraws from 60/minute to 1-2/minute during paused/deferred states, eliminating visible stutter during Space-switching animations.

**3. Frontmost app cache**: Querying `NSWorkspace.shared.frontmostApplication` involves IPC with WindowServer. The app caches the result for 2 seconds:

```swift
private var cachedExcludedBundleID: String?
private var lastExclusionCheck: TimeInterval = 0

func isExcludedAppFrontmost() -> Bool {
    let now = ProcessInfo.processInfo.systemUptime
    if now - lastExclusionCheck > 2 {
        lastExclusionCheck = now
        cachedExcludedBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    guard let bundleID = cachedExcludedBundleID else { return false }
    return Preferences.shared.excludedBundleIDs.contains(bundleID)
}
```

### Timer Intervals & Power Efficiency

| Timer | Interval | Leeway | Purpose |
|-------|----------|--------|---------|
| Main break timer | 1.0s | None | UI countdown accuracy |
| Idle detector poll | 5.0s | 1.0s | Power-efficient coalescing |
| Snooze timer | 1.0s | None | UI countdown accuracy |
| Frontmost app cache | 2.0s | — | IPC reduction |

The 1-second leeway on the 5-second idle poll allows macOS to coalesce the timer with other system work, reducing CPU wake-ups on battery power.

---

## Data Persistence & Statistics

### Statistics Storage

Daily break records are persisted as JSON in `~/Library/Application Support/CountTongula/statistics.json`:

```swift
struct DayStats: Codable {
    var date: String      // "YYYY-MM-DD"
    var completed: Int
    var skipped: Int
    var snoozed: Int
}

struct StatsData: Codable {
    var days: [DayStats]
    var longestStreak: Int
    var currentStreakCount: Int
}
```

Writes are atomic (`Data.WritingOptions.atomic`) to prevent corruption if the app is killed mid-write. Records older than 30 days are pruned on each save to bound storage growth.

### Streak & Approval Metrics

- **Streak**: Incremented on each completed break, reset to 0 on skip. Snoozes don't affect streak.
- **Approval rating**: `completed / (completed + skipped) * 100`. Snoozes are excluded from the denominator — they represent deferral, not rejection.
- **Milestones**: Triggered at 5, 10, 25, 50, and 100 completed breaks with themed vampire rank titles.

---

## Security Model

### Principle of Least Privilege

- **No elevated permissions**: Runs entirely as a user process. Never requests admin/sudo.
- **No TCC entitlements**: Core functionality requires zero privacy permissions. IOKit access is allowed by default.
- **No network activity except updates**: No telemetry, analytics, or tracking. The only outbound request is Sparkle fetching `appcast.xml`.

### Code Signing

The app is ad-hoc signed (`codesign --sign -`), meaning no Apple Developer certificate is required. Users must clear the quarantine attribute on first launch:

```bash
xattr -cr "/Applications/Count Tongula's Eye Break.app"
```

### Update Security

Sparkle's EdDSA signature verification ensures:

- The update DMG was signed by the developer's private key
- The DMG hasn't been tampered with in transit (MITM protection)
- A compromised GitHub account can't push malicious updates without the Keychain-stored private key

### Sound Playback

System sounds are played via `afplay` subprocess rather than `NSSound`. This avoids the microphone permission prompt that `NSSound` (and `UNUserNotificationCenter`) trigger on macOS 26, where Apple unified audio input/output authorization.

---

## Testing & Developer Tooling

### Built-in Screenshot & Demo Modes

The executable accepts command-line flags for automated testing and marketing asset generation:

```bash
# Generate all 8 marketing screenshots
./eye_break_ui --screenshot-all --outdir=/tmp/screenshots

# Interactive gallery mode (arrow keys to navigate)
./eye_break_ui --gallery

# Live demo playthrough (3s per screen)
./eye_break_ui --demo

# Test a specific break type interactively
./eye_break_ui --trigger-eye
./eye_break_ui --trigger-long
```

Screenshot mode uses sequential `DispatchQueue.main.asyncAfter` chains to render each screen, wait for layout, capture via `captureWindow()`, then advance to the next screen. This is CI-friendly — no human interaction required.

### Single-Instance Guard

A POSIX `flock` on `/tmp/com.counttongula.eyebreak.lock` prevents duplicate instances:

```swift
let lockFD = open("/tmp/com.counttongula.eyebreak.lock", O_WRONLY | O_CREAT, 0o600)
if lockFD < 0 || flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
    fputs("Another instance is already running.\n", stderr)
    exit(0)
}
```

Dev modes (`--gallery`, `--demo`, `--screenshot*`) skip the lock check so testing instances can run alongside the production app.

### Legacy Migration

The app includes a `removeLegacyLaunchAgent()` method that cleans up LaunchAgent plists from older versions. When a user upgrades from a version that used LaunchAgent-based login items to the current version (which uses macOS native Login Items via the .app bundle), the old plist is unloaded via `launchctl bootout` and deleted. This prevents duplicate entries in System Settings.

---

## Key Design Decisions & Trade-offs

| Decision | Choice | Alternative Considered | Why |
|----------|--------|----------------------|-----|
| Build system | SwiftPM executable target | Xcode project | Reproducibility, CI simplicity, no IDE lock-in |
| Universal binary | Separate builds + lipo | Single multi-arch build | SwiftPM multi-arch triggers xcodebuild pathway, breaks Lottie |
| Idle detection | IOKit + CGEventSource + file I/O | Private frameworks, heuristics | Most reliable; no private API risk |
| Polling architecture | Background DispatchQueue, 5s interval | Main thread, 1s interval | Eliminates compositor stutter during Space switching |
| Layout system | Frame-based for fixed windows, Auto Layout for dynamic | All Auto Layout | Simpler reasoning for fixed-size windows; no constraint debugging |
| Sound playback | afplay subprocess | NSSound | Avoids mic permission prompt on macOS 26 |
| Theme | Hardcoded Dracula palette | System appearance, user-configurable | Strong brand identity; consistent across light/dark system modes |
| Auto-update | Sparkle 2.x with EdDSA | Custom GitHub API polling | Industry standard; handles download/verify/install/relaunch |
| Font loading | CoreText process-scope registration | NSFontManager, system install | No system-wide side effects; graceful fallback |
| Statistics | JSON file in Application Support | SQLite, Core Data | Human-readable; simple Codable serialization; 30-day bounded |
| Single instance | POSIX flock | NSDistributedNotificationCenter | Works without app bundle; no IPC overhead |
| DND detection | File I/O on Assertions.json | No DND awareness | Undocumented but stable; no public API alternative exists |

---

## File Structure

```
scripts/Sources/
    main.swift                      Entry point, mode routing, single-instance guard
    AppDelegate.swift               Menu bar, timer loop, break orchestration
    BreakWindowController.swift     Break UI (prompt, countdown, complete), multi-monitor
    IdleDetector.swift              System sleep, screen lock, DND, input idle
    Preferences.swift               UserDefaults wrapper with reactive notifications
    Statistics.swift                 JSON persistence, streaks, milestones, approval rating
    Theme.swift                     Dracula palette, CoreText fonts, HoverButton/HoverLink/ProgressBar
    SoundManager.swift              afplay subprocess wrapper
    Quotes.swift                    Vampire-themed quote arrays
    OnboardingController.swift      First-run configuration flow
    SettingsWindowController.swift  Two-column preference panel
    StatsChartWindowController.swift  30-day history visualization
    FeedbackWindowController.swift  Bug report / feature request forms

build-app.sh                        Build pipeline: compile, bundle, sign, package, appcast
Package.swift                       SPM manifest
appcast.xml                         Sparkle auto-update feed (auto-generated by build script)
```
