# CleanMyScreen architecture

## Application layer

`CleanMyScreenApp` owns one `LockSessionCoordinator` and exposes both a normal SwiftUI window and a `MenuBarExtra`. The coordinator is the only object allowed to start or stop a session, which keeps teardown behavior consistent across the main button, menu bar, timer, emergency gesture, display changes, and app termination.

## Lock lifecycle

1. Validate the selected mode and device choices.
2. Show a three-second cancelable countdown.
3. Acquire required input-monitoring access and device handles.
4. Confirm the input tap/device seizure is active.
5. Apply brightness changes and overlays only after input blocking succeeds.
6. Start the optional automatic-unlock timer.
7. On every exit path, stop the event tap, release HID devices, close overlays, unhide the cursor, and restore saved brightness.

Failure is deliberately **fail-open**: if an input tap is disabled, access is revoked, hardware cannot be seized, or the app exits, macOS input becomes available again.

## Services

- `SystemInputBlocker`: filters session-level Core Graphics events and detects the three-second Escape emergency gesture.
- `SystemHIDDeviceBlocker`: best-effort device-specific locking for built-in trackpads and compatible external HID devices.
- `DisplayOverlayController`: manages one black AppKit window per display and transient nonblocking status HUDs.
- `SystemBrightnessController`: best-effort brightness adjustment with per-display value restoration.

## Privacy and networking

The application has no networking dependency, analytics SDK, account system, persistence backend, or keystroke storage. Input callbacks inspect only event categories and whether Escape is pressed for emergency unlock; all blocked events are discarded immediately.
