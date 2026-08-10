# CleanMyScreen

CleanMyScreen is a native macOS utility built with SwiftUI, AppKit, Core Graphics, and IOKit. The first release keeps every mode fully available without accounts, payments, trials, subscriptions, telemetry, or network access.

The app icon uses a sea-otter mascot in a forest-green palette. The mascot represents the cleaning workflow without implying that CleanMyScreen is a security boundary.

## Downloads

Release images are written to `dist/releases/` by `./Scripts/build-dmgs.sh`:

- `CleanMyScreen-arm64.dmg` for Apple Silicon Macs (M1, M2, M3, M4 and newer)
- `CleanMyScreen-x86_64.dmg` for Intel Macs

These local builds are ad-hoc signed. On first launch, macOS may require opening the app from Finder and confirming it in Privacy & Security. Input Monitoring is required only when a session locks input; the app provides a button that opens the exact System Settings pane.

## Modes

- **Cleaning** covers one or every display in pure black, attempts to maximize supported display brightness, and temporarily blocks keyboard and pointer input.
- **Pet / Kid** leaves the current video or webpage visible while temporarily blocking accidental input.
- **Selective** can lock the keyboard, the built-in trackpad, compatible external input devices, or a combination.

Every session has a three-second countdown, a three-second Escape-key emergency unlock gesture, and an optional automatic timeout. Ending a session restores overlays, the cursor, seized devices, and any brightness values the app was able to change.

## Build and run

The repository can be built with Apple's Swift command-line tools:

```sh
./Scripts/run-tests.sh
./Scripts/build-app.sh
./Scripts/build-dmgs.sh
open dist/CleanMyScreen.app
```

`run-tests.sh` uses Swift Testing's bundled framework because Command Line Tools alone do not include the `xctest` launcher. With full Xcode installed, `swift test` can be used directly.

The build script produces a universal Apple Silicon + Intel application bundle and applies an ad-hoc local signature.

`build-dmgs.sh` thins that universal bundle into separate architecture-specific DMGs and verifies each disk image checksum.

Installing full Xcode is only required for an Xcode project workflow, Developer ID signing, notarization, or App Store distribution. The current brightness implementation uses a private CoreDisplay fallback, so an App Store build must replace or disable that capability before submission; the local/Developer ID build is the intended first distribution path.

## macOS system access

macOS requires **Input Monitoring** approval before an app can observe and suppress input sent to other applications. CleanMyScreen requests that system control only when a lock session needs it. If macOS no longer repeats its own permission prompt, the app presents a button that opens the exact Input Monitoring pane. On configurations where an active event filter is still denied, the same flow links directly to Accessibility as a compatibility fallback. These are operating-system requirements, not account or product restrictions. The app does not record, store, transmit, or inspect keystroke contents.

## Hardware limits

- Brightness control is best-effort because macOS has no single public brightness API for every built-in and external display. Unsupported displays stay at their current brightness.
- Device-specific trackpad and external-device locking depends on what the connected HID hardware and macOS allow the app to seize. If the device cannot be safely isolated, the app reports the limitation and leaves input available.
- On a desktop Mac with no built-in keyboard, one external keyboard is deliberately kept available for the emergency unlock gesture. Devices connected after a session starts may remain available until that session is restarted.
- CleanMyScreen is an accidental-input guard, not a login lock, parental-control boundary, or security product. Power, Touch ID, force quit, and other system-reserved operations remain available.

## License

CleanMyScreen is released under the MIT License. See [LICENSE](LICENSE).
