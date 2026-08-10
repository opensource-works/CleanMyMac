import Foundation

public struct InputBlockMask: OptionSet, Sendable, Equatable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let keyboard = InputBlockMask(rawValue: 1 << 0)
    public static let pointer = InputBlockMask(rawValue: 1 << 1)
    public static let scrolling = InputBlockMask(rawValue: 1 << 2)
    public static let gestures = InputBlockMask(rawValue: 1 << 3)
    /// Starts a minimal event tap so the emergency unlock chord remains
    /// available while device-specific HID locks are active.
    public static let emergencyUnlockOnly = InputBlockMask(rawValue: 1 << 7)
    public static let all: InputBlockMask = [.keyboard, .pointer, .scrolling, .gestures]
}

public struct SelectiveLockConfiguration: Sendable, Equatable {
    public var keyboard: Bool
    public var trackpad: Bool
    public var externalDevices: Bool

    public init(keyboard: Bool = true, trackpad: Bool = false, externalDevices: Bool = false) {
        self.keyboard = keyboard
        self.trackpad = trackpad
        self.externalDevices = externalDevices
    }

    public var hasSelection: Bool {
        keyboard || trackpad || externalDevices
    }
}

public struct LockConfiguration: Sendable, Equatable {
    public var mode: LockMode
    public var allDisplays: Bool
    public var maximizeBrightness: Bool
    public var autoUnlockSeconds: TimeInterval?
    public var selective: SelectiveLockConfiguration

    public init(
        mode: LockMode,
        allDisplays: Bool = true,
        maximizeBrightness: Bool = true,
        autoUnlockSeconds: TimeInterval? = 60,
        selective: SelectiveLockConfiguration = .init()
    ) {
        self.mode = mode
        self.allDisplays = allDisplays
        self.maximizeBrightness = maximizeBrightness
        self.autoUnlockSeconds = autoUnlockSeconds
        self.selective = selective
    }
}
