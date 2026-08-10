@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

/// Blocks selected classes of input at the current login session's event tap.
///
/// `SystemInputBlocker` always observes key events while it is active so the
/// long-press Escape action remains available. Those keyboard events are only
/// swallowed when keyboard blocking was requested.
public final class SystemInputBlocker: InputBlocking, @unchecked Sendable {
    static let emergencyHoldDuration: TimeInterval = 3

    private let stateLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var blockingMask = InputBlockMask()
    private var emergencyUnlock: (@Sendable () -> Void)?
    private var emergencyEscapeState = EmergencyEscapeState()
    private var emergencyWorkItem: DispatchWorkItem?
    private var holdGeneration: UInt64 = 0
    private var didTriggerEmergencyUnlock = false

    public init() {}

    deinit {
        stop()
    }

    public var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return eventTap != nil
    }

    /// Requests macOS Input Monitoring access when it has not already been
    /// granted. macOS owns the resulting consent UI and may require the user to
    /// enable the app in System Settings before this returns `true`.
    public func requestMonitoringAccess() -> Bool {
        CGPreflightListenEventAccess() || CGRequestListenEventAccess()
    }

    public func start(
        blocking mask: InputBlockMask,
        onEmergencyUnlock: @escaping @Sendable () -> Void
    ) throws {
        guard !mask.isEmpty else {
            throw CleanMyScreenError.noSelectiveInputChosen
        }

        guard CGPreflightListenEventAccess() else {
            throw CleanMyScreenError.inputMonitoringRequired
        }

        stateLock.lock()
        guard eventTap == nil else {
            stateLock.unlock()
            throw CleanMyScreenError.alreadyActive
        }
        stateLock.unlock()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.tapEventMask(for: mask),
            callback: systemInputEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // Current macOS releases authorize event taps through Input
            // Monitoring. Older configurations may still apply the legacy
            // Accessibility requirement documented for active taps; only ask
            // for that broader permission after creation actually fails.
            if !AXIsProcessTrusted() {
                let options = [
                    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
                ] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            }
            throw CleanMyScreenError.inputTapUnavailable
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw CleanMyScreenError.inputTapUnavailable
        }

        stateLock.lock()
        guard eventTap == nil else {
            stateLock.unlock()
            CFRunLoopSourceInvalidate(source)
            CFMachPortInvalidate(tap)
            throw CleanMyScreenError.alreadyActive
        }

        blockingMask = mask
        emergencyUnlock = onEmergencyUnlock
        emergencyEscapeState.reset()
        holdGeneration &+= 1
        didTriggerEmergencyUnlock = false
        eventTap = tap
        runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        stateLock.unlock()
    }

    public func stop() {
        stateLock.lock()
        let tap = eventTap
        let source = runLoopSource
        let workItem = emergencyWorkItem

        eventTap = nil
        runLoopSource = nil
        blockingMask = []
        emergencyUnlock = nil
        emergencyWorkItem = nil
        emergencyEscapeState.reset()
        holdGeneration &+= 1
        didTriggerEmergencyUnlock = false
        stateLock.unlock()

        workItem?.cancel()

        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
    }

    static func shouldBlock(eventType: CGEventType, with mask: InputBlockMask) -> Bool {
        let rawValue = eventType.rawValue

        if keyboardEventTypeRawValues.contains(rawValue) {
            return mask.contains(.keyboard)
        }
        if pointerEventTypeRawValues.contains(rawValue) {
            return mask.contains(.pointer)
        }
        if rawValue == CGEventType.scrollWheel.rawValue {
            return mask.contains(.scrolling)
        }
        if gestureEventTypeRawValues.contains(rawValue) {
            return mask.contains(.gestures)
        }
        return false
    }

    static func tapEventMask(for mask: InputBlockMask) -> CGEventMask {
        // keyDown/keyUp are observed even for a pointer-only or HID-only lock
        // so long-press Escape remains available. `shouldBlock` still passes
        // these events through unless keyboard blocking was explicitly
        // requested.
        var rawValues: Set<UInt32> = [
            CGEventType.keyDown.rawValue,
            CGEventType.keyUp.rawValue,
        ]

        if mask.contains(.keyboard) {
            rawValues.formUnion(keyboardEventTypeRawValues)
        }
        if mask.contains(.pointer) {
            rawValues.formUnion(pointerEventTypeRawValues)
        }
        if mask.contains(.scrolling) {
            rawValues.insert(CGEventType.scrollWheel.rawValue)
        }
        if mask.contains(.gestures) {
            rawValues.formUnion(gestureEventTypeRawValues)
        }

        return rawValues.reduce(CGEventMask(0)) { result, rawValue in
            result | (CGEventMask(1) << CGEventMask(rawValue))
        }
    }

    fileprivate func handleTapEvent(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reenableTapIfNeeded()
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown || type == .keyUp {
            observeEmergencyEscape(type: type, event: event)
        }

        stateLock.lock()
        let mask = blockingMask
        let running = eventTap != nil
        stateLock.unlock()

        guard running, Self.shouldBlock(eventType: type, with: mask) else {
            return Unmanaged.passUnretained(event)
        }
        return nil
    }

    private func reenableTapIfNeeded() {
        stateLock.lock()
        let tap = eventTap
        let workItem = emergencyWorkItem
        emergencyWorkItem = nil
        emergencyEscapeState.reset()
        holdGeneration &+= 1
        didTriggerEmergencyUnlock = false
        stateLock.unlock()

        // A disabled tap may have missed one side of the key-up sequence. Reset
        // Escape so a stale state cannot unlock the app after re-enabling.
        workItem?.cancel()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func observeEmergencyEscape(type: CGEventType, event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == EmergencyEscapeState.escapeKeyCode else { return }

        var workItemToSchedule: DispatchWorkItem?

        stateLock.lock()
        guard eventTap != nil else {
            stateLock.unlock()
            return
        }

        let transition = emergencyEscapeState.update(eventType: type)

        if transition == .pressed,
           emergencyWorkItem == nil,
           !didTriggerEmergencyUnlock {
            holdGeneration &+= 1
            let generation = holdGeneration
            let workItem = DispatchWorkItem { [weak self] in
                self?.completeEmergencyHold(generation: generation)
            }
            emergencyWorkItem = workItem
            workItemToSchedule = workItem
        } else if transition == .released {
            emergencyWorkItem?.cancel()
            emergencyWorkItem = nil
            holdGeneration &+= 1
            didTriggerEmergencyUnlock = false
        }
        stateLock.unlock()

        if let workItemToSchedule {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.emergencyHoldDuration,
                execute: workItemToSchedule
            )
        }
    }

    private func completeEmergencyHold(generation: UInt64) {
        stateLock.lock()
        guard eventTap != nil,
              generation == holdGeneration,
              emergencyEscapeState.escapeIsDown,
              !didTriggerEmergencyUnlock else {
            stateLock.unlock()
            return
        }

        didTriggerEmergencyUnlock = true
        emergencyWorkItem = nil
        let callback = emergencyUnlock
        stateLock.unlock()

        callback?()
    }

    private static let keyboardEventTypeRawValues: Set<UInt32> = [
        CGEventType.keyDown.rawValue,
        CGEventType.keyUp.rawValue,
        CGEventType.flagsChanged.rawValue,
        14, // NSEvent.EventType.systemDefined (media and auxiliary keys)
    ]

    private static let pointerEventTypeRawValues: Set<UInt32> = [
        CGEventType.leftMouseDown.rawValue,
        CGEventType.leftMouseUp.rawValue,
        CGEventType.rightMouseDown.rawValue,
        CGEventType.rightMouseUp.rawValue,
        CGEventType.mouseMoved.rawValue,
        CGEventType.leftMouseDragged.rawValue,
        CGEventType.rightMouseDragged.rawValue,
        CGEventType.otherMouseDown.rawValue,
        CGEventType.otherMouseUp.rawValue,
        CGEventType.otherMouseDragged.rawValue,
        CGEventType.tabletPointer.rawValue,
        CGEventType.tabletProximity.rawValue,
        34, // NSEvent.EventType.pressure
    ]

    /// AppKit exposes gesture event types that CoreGraphics does not name in
    /// `CGEventType`; event taps still use their stable NSEvent raw values.
    private static let gestureEventTypeRawValues: Set<UInt32> = [
        18, // rotate
        19, // beginGesture
        20, // endGesture
        29, // gesture
        30, // magnify
        31, // swipe
        32, // smartMagnify
        37, // directTouch
        38, // changeMode
    ]
}

/// Pure state machine for the emergency Escape long press.
enum EmergencyEscapeTransition: Sendable, Equatable {
    case pressed
    case released
    case unchanged
}

struct EmergencyEscapeState: Sendable {
    static let escapeKeyCode: Int64 = 53

    private(set) var escapeIsDown = false

    mutating func update(eventType: CGEventType) -> EmergencyEscapeTransition {
        switch eventType {
        case .keyDown:
            guard !escapeIsDown else { return .unchanged }
            escapeIsDown = true
            return .pressed
        case .keyUp:
            guard escapeIsDown else { return .unchanged }
            escapeIsDown = false
            return .released
        default:
            return .unchanged
        }
    }

    mutating func reset() {
        escapeIsDown = false
    }
}

private func systemInputEventTapCallback(
    proxy _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let blocker = Unmanaged<SystemInputBlocker>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return blocker.handleTapEvent(type: type, event: event)
}
