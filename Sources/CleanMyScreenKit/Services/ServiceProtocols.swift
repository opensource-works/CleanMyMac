import AppKit
import Foundation

public enum CleanMyScreenError: LocalizedError, Equatable {
    case inputMonitoringRequired
    case inputTapUnavailable
    case noSelectiveInputChosen
    case trackpadUnavailable
    case externalDevicesUnavailable
    case alreadyActive

    public var errorDescription: String? {
        switch self {
        case .inputMonitoringRequired:
            "Allow CleanMyScreen in Input Monitoring. If it is already on, turn it off and on again, then reopen CleanMyScreen."
        case .inputTapUnavailable:
            "macOS still did not allow CleanMyScreen to create an input lock. Enable it in Accessibility; if it is already on, turn it off and on again, then reopen CleanMyScreen."
        case .noSelectiveInputChosen:
            "Choose at least one input device to lock."
        case .trackpadUnavailable:
            "The built-in trackpad could not be locked on this Mac."
        case .externalDevicesUnavailable:
            "No compatible external input devices could be locked."
        case .alreadyActive:
            "A lock session is already active."
        }
    }
}

public protocol InputBlocking: AnyObject {
    var isRunning: Bool { get }
    func requestMonitoringAccess() -> Bool
    func start(blocking mask: InputBlockMask, onEmergencyUnlock: @escaping @Sendable () -> Void) throws
    func stop()
}

public protocol HIDDeviceBlocking: AnyObject {
    var blockedDeviceNames: [String] { get }
    var failedDeviceNames: [String] { get }
    func blockBuiltInTrackpads() throws -> Int
    func blockExternalInputDevices() throws -> Int
    func stop()
}

@MainActor
public protocol OverlayControlling: AnyObject {
    var isShowingCleaningOverlay: Bool { get }
    func showCleaningOverlay(onAllDisplays: Bool, unlockHint: String)
    func showPreparationHUD(secondsRemaining: Int)
    func showTransientHUD(title: String, detail: String)
    func hideAll()
}

@MainActor
public protocol BrightnessControlling: AnyObject {
    var supportedDisplayCount: Int { get }
    func maximizeSupportedDisplays()
    func restore()
}
