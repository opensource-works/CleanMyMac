import CoreGraphics
import Testing
@testable import CleanMyScreenKit

@Test("Input event categories are blocked independently")
func inputEventCategoriesAreIndependent() {
    #expect(SystemInputBlocker.shouldBlock(eventType: .keyDown, with: [.keyboard]))
    #expect(!SystemInputBlocker.shouldBlock(eventType: .mouseMoved, with: [.keyboard]))
    #expect(SystemInputBlocker.shouldBlock(eventType: .mouseMoved, with: [.pointer]))
    #expect(SystemInputBlocker.shouldBlock(eventType: .scrollWheel, with: [.scrolling]))
    #expect(!SystemInputBlocker.shouldBlock(eventType: .scrollWheel, with: [.gestures]))

    let systemDefinedMediaKey = CGEventType(rawValue: 14)!
    #expect(SystemInputBlocker.shouldBlock(
        eventType: systemDefinedMediaKey,
        with: [.keyboard]
    ))

    let magnify = CGEventType(rawValue: 30)!
    #expect(SystemInputBlocker.shouldBlock(eventType: magnify, with: [.gestures]))
    #expect(!SystemInputBlocker.shouldBlock(eventType: magnify, with: [.scrolling]))
}

@Test("Pointer-only and HID-only taps observe Escape without blocking keys")
func nonKeyboardTapsObserveEscapeWithoutBlockingKeys() {
    let pointerOnlyMask = SystemInputBlocker.tapEventMask(for: [.pointer])
    let emergencyOnlyMask = SystemInputBlocker.tapEventMask(for: [.emergencyUnlockOnly])
    let keyDownBit = CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue)
    let keyUpBit = CGEventMask(1) << CGEventMask(CGEventType.keyUp.rawValue)

    #expect(pointerOnlyMask & keyDownBit != 0)
    #expect(pointerOnlyMask & keyUpBit != 0)
    #expect(emergencyOnlyMask == keyDownBit | keyUpBit)
    #expect(!SystemInputBlocker.shouldBlock(
        eventType: .keyDown,
        with: [.pointer]
    ))
    #expect(!SystemInputBlocker.shouldBlock(
        eventType: .keyDown,
        with: [.emergencyUnlockOnly]
    ))
    #expect(SystemInputBlocker.shouldBlock(
        eventType: .keyDown,
        with: [.keyboard]
    ))
}

@Test("Escape starts once, ignores auto-repeat, and cancels on keyUp")
func emergencyEscapeTransitions() {
    var state = EmergencyEscapeState()

    #expect(SystemInputBlocker.emergencyHoldDuration == 3)
    #expect(state.update(eventType: .keyDown) == .pressed)
    #expect(state.escapeIsDown)
    #expect(state.update(eventType: .keyDown) == .unchanged)
    #expect(state.escapeIsDown)
    #expect(state.update(eventType: .keyUp) == .released)
    #expect(!state.escapeIsDown)
    #expect(state.update(eventType: .keyUp) == .unchanged)
}

@Test("HID target matching separates built-in trackpads and external input")
func hidTargetMatching() {
    let builtInTrackpad = HIDDeviceProfile(
        name: "MacBook Trackpad",
        isBuiltIn: true,
        isKeyboard: false,
        isPointer: true,
        isTouchpad: true
    )
    let builtInKeyboard = HIDDeviceProfile(
        name: "Internal Keyboard",
        isBuiltIn: true,
        isKeyboard: true,
        isPointer: false,
        isTouchpad: false
    )
    let externalMouse = HIDDeviceProfile(
        name: "USB Mouse",
        isBuiltIn: false,
        isKeyboard: false,
        isPointer: true,
        isTouchpad: false
    )

    #expect(HIDBlockTarget.builtInTrackpad.matches(builtInTrackpad))
    #expect(!HIDBlockTarget.builtInTrackpad.matches(builtInKeyboard))
    #expect(!HIDBlockTarget.externalInput.matches(builtInTrackpad))
    #expect(HIDBlockTarget.externalInput.matches(externalMouse))
}
