# Roadmap

What's planned, in progress, and done.

## In Progress

- **Apple Developer ID code signing + notarization** — Eliminates the "malicious software" Gatekeeper warning on first launch. No more `xattr -cr` workaround. Requires $99/year Apple Developer Program enrollment.

## Planned

- **Notarized DMG distribution** — Once code signing is set up, integrate `xcrun notarytool submit` and `xcrun stapler staple` into `build-app.sh` so every release is automatically notarized.
- **Remove Homebrew `xattr` postflight hack** — After notarization, the cask formula no longer needs `sudo xattr -cr` in the postflight script.
- **GitHub Actions release workflow update** — Current CI workflow is outdated. Update to build universal binary, sign with Developer ID, notarize, and publish release + update Homebrew cask in one pipeline.

## Done

- Sparkle auto-update integration (v0.10.0)
- Universal binary support for Intel + Apple Silicon (v0.8.0)
- Multi-monitor companion windows
- Long break scheduling (every N eye breaks)
- Idle detection (IOKit screen lock, CGEventSource input idle, DND file polling)
- Sleep/wake handling (defer breaks during sleep, dismiss break window on wake)
- App exclusion (pause during Zoom, Keynote, OBS, etc.)
- Strict mode (prevent skipping breaks)
- Statistics tracking with 30-day history and streak milestones
- Lottie vector animations during breaks
- Dracula theme with DM Sans/Mono custom fonts
- Onboarding flow for first-time setup
- Bug report and feature request forms
- Sound customization (14 system sounds)
