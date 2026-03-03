# 🧛 Count Tongula's Eye Break Reminder

**A persistent macOS menu bar app that reminds you to rest your eyes every 20 minutes of active screen time.**

Follows the [20-20-20 rule](https://www.healthline.com/health/eye-health/20-20-20-rule): every **20 minutes**, look at something **20 feet** away for **20 seconds**.

<p align="center">
<img src="https://img.shields.io/badge/platform-macOS-bd93f9?style=flat-square" alt="macOS">
<img src="https://img.shields.io/badge/swift-AppKit-ff79c6?style=flat-square" alt="Swift">
<img src="https://img.shields.io/badge/theme-dracula-6272a4?style=flat-square" alt="Dracula">
</p>

<p align="center">
<img src="screenshots/screenshot-prompt.png" width="420" alt="Break prompt with vampire quote">
<img src="screenshots/screenshot-countdown.png" width="420" alt="20-second countdown">
</p>

<p align="center">
<img src="screenshots/screenshot-complete.png" width="420" alt="Break complete">
</p>

---

## Table of Contents

- [Features](#features)
- [Install](#install)
- [Uninstall](#uninstall)
- [How It Works](#how-it-works)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Configuration](#configuration)
- [Statistics & Gamification](#statistics--gamification)
- [Requirements](#requirements)
- [License](#license)

---

## Features

- **Menu bar app** -- lives in your menu bar as a 🦇 icon with a live countdown to your next break
- **Dracula theme** -- native AppKit windows styled with the [Dracula](https://draculatheme.com) color palette and mascot
- **Random vampire quotes** -- a different Bram Stoker-inspired quote for prompts, countdowns, completions, and stretch breaks
- **Smart timer** -- only counts active screen time; pauses when your screen is locked, your Mac sleeps, or macOS Focus/DND is active
- **Idle detection** -- detects keyboard and mouse inactivity via `CGEventSource`; resets the timer when you're already away (counts as a natural break)
- **Configurable intervals** -- adjust break interval (5-60 min), break duration (10-60 sec), and snooze duration (1-10 min) from the Settings panel
- **Sound customization** -- choose from 14 macOS system sounds for the break prompt and completion chime, with live preview
- **Snooze support** -- not ready? Snooze for a configurable duration (one snooze per break cycle)
- **Guided countdown** -- 20-second countdown with a purple progress bar
- **Long break mode** -- every N eye breaks, triggers a longer 5-minute stretch break with dedicated stretch quotes from the Count
- **Multi-monitor support** -- optional fullscreen overlay on all connected screens
- **Global keyboard shortcuts** -- trigger a break or pause/resume from anywhere
- **Statistics & gamification** -- tracks breaks completed, skipped, and snoozed per day; streak tracking with vampire-themed milestone titles
- **Onboarding** -- first-run welcome screen explaining the 20-20-20 rule with interval and duration configuration
- **Mascot animation** -- gentle floating animation on the vampire mascot using Core Animation
- **Runs at login** -- installs as a macOS LaunchAgent

## Install

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/alextongme/count-tongulas-eye-break.git
cd eye-break-reminder
./install.sh
```

The installer compiles all Swift sources into a single `eye_break_ui` binary, symlinks everything to `~/.eye-break/`, and loads the LaunchAgent. Count Tongula appears in your menu bar immediately and on every login.

Updates are instant -- just pull:

```bash
cd eye-break-reminder
git pull && ./install.sh
```

## Uninstall

```bash
cd eye-break-reminder
./uninstall.sh
```

## How It Works

```
scripts/Sources/*.swift  -->  eye_break_ui (single binary)
                              compiled with swiftc

  Menu Bar (NSStatusItem)
  ┌─────────────────────────────────────────────────┐
  │  🦇 18:42                                       │
  │ ┌─────────────────────────────────────────────┐ │
  │ │  Next break in 18:42                        │ │
  │ │  Today: 5 breaks, 1 skipped                 │ │
  │ │  Streak: 5 breaks                           │ │
  │ │  Approval rating: 83%                       │ │
  │ │  ─────────────────────                      │ │
  │ │  Pause / Resume                             │ │
  │ │  Take a Break Now                           │ │
  │ │  Settings...                                │ │
  │ │  Quit Count Tongula                         │ │
  │ └─────────────────────────────────────────────┘ │
  └────────┬────────────────────────┬───────────────┘
           │                        │
           v                        v
  Break Window               Settings Window
  ┌───────────────────┐      ┌───────────────────┐
  │ 🧛 Mascot         │      │  Timing           │
  │ Vampire quote     │      │  Sounds           │
  │ [Start] [Snooze]  │      │  Behavior         │
  │         |         │      │  Long Breaks      │
  │    20s countdown  │      └───────────────────┘
  │    + progress bar │
  │         |         │
  │  "Break complete" │
  └───────────────────┘

  Supporting Systems
  ┌─────────────────────────────────────────────────┐
  │  IdleDetector   - CGEventSource idle time       │
  │                 - Sleep/wake notifications       │
  │                 - Screen lock via IOKit          │
  │                 - DND/Focus mode awareness       │
  │  Statistics     - ~/Library/Application Support/ │
  │                   CountTongula/statistics.json   │
  │  Preferences    - UserDefaults persistence       │
  │  SoundManager   - 14 macOS system sounds         │
  │  Onboarding     - First-run configuration        │
  └─────────────────────────────────────────────────┘
```

**Single binary architecture** -- the app is a persistent Swift menu bar application compiled from 11 source files in `scripts/Sources/`. No bash daemon, no Python dependencies. The binary runs as a standard macOS `NSApplication` with an `NSStatusItem` in the menu bar.

**Break flow** -- when the timer reaches zero, the app plays the prompt sound and opens a break window with three phases:
1. **Prompt** -- shows the Dracula mascot, a random vampire quote, and Start Break / Snooze buttons
2. **Countdown** -- a 20-second guided countdown with a progress bar and countdown-specific quotes
3. **Complete** -- a congratulatory message from the Count and an auto-dismiss timer

**Idle intelligence** -- the timer resets automatically when the user has been idle past the configured threshold (default: 5 minutes), since the user already took a natural break. Breaks are deferred entirely when the system is sleeping, the screen is locked, or macOS Focus/DND mode is active.

**Long breaks** -- every N eye breaks (default: 3), the app triggers a longer 5-minute stretch break instead. These use dedicated stretch break quotes from the Count encouraging the user to stand, walk, and stretch.

## Keyboard Shortcuts

These global shortcuts work from any application:

| Shortcut | Action |
|----------|--------|
| `Cmd + Shift + B` | Take a break now |
| `Cmd + Shift + P` | Pause / resume timer |

## Configuration

Open Settings from the menu bar dropdown. The Settings panel has four sections:

### Timing

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| Break interval | 5 - 60 min | 20 min | Time between eye breaks |
| Break duration | 10 - 60 sec | 20 sec | Length of the guided countdown |
| Snooze duration | 1 - 10 min | 5 min | How long a snooze lasts |

### Sounds

| Setting | Default | Description |
|---------|---------|-------------|
| Sound enabled | On | Master toggle for all sounds |
| Prompt sound | Basso | Sound played when a break starts |
| Complete sound | Hero | Sound played when a break finishes |

Choose from 14 macOS system sounds: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink. Each can be previewed from the Settings panel.

### Behavior

| Setting | Default | Description |
|---------|---------|-------------|
| DND aware | On | Pause breaks during macOS Focus/Do Not Disturb |
| Idle detection | On | Reset timer when user is idle (natural break) |
| Fullscreen overlay | Off | Show break overlay on all connected monitors |
| Launch at login | On | Start Count Tongula automatically at login |

### Long Breaks

| Setting | Default | Description |
|---------|---------|-------------|
| Long breaks enabled | On | Enable periodic longer stretch breaks |
| Frequency | Every 3 eye breaks | How many eye breaks between long breaks |
| Duration | 5 min | Length of the stretch break |

All settings are persisted via `UserDefaults` and take effect immediately.

## Statistics & Gamification

Count Tongula tracks your devotion. Statistics are stored in `~/Library/Application Support/CountTongula/statistics.json` and retained for 30 days.

**Daily stats** (visible in the menu bar dropdown):
- Breaks completed
- Breaks skipped
- Breaks snoozed
- Approval rating (completed / total as a percentage)

**Streak tracking** -- consecutive breaks completed without skipping. Skipping a break resets the streak. Snoozing does not break your streak.

**Milestone titles** -- unlock vampire-themed ranks as your streak grows:

| Streak | Title |
|--------|-------|
| 5 | Familiar |
| 10 | Servant of the Night |
| 25 | Thrall |
| 50 | Considered for immortality |
| 100 | Order of Count Tongula |

## Requirements

- macOS 12+ (Monterey or later)
- Xcode Command Line Tools (for `swiftc`)

## License

MIT -- Dracula mascot artwork belongs to the [Dracula Theme](https://draculatheme.com) project.
