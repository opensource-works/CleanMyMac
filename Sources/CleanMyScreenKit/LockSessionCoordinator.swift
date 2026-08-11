import Combine
import Foundation

public enum PermissionSettingsDestination: Sendable, Equatable {
    case inputMonitoring
    case accessibility
}

@MainActor
public final class LockSessionCoordinator: ObservableObject {
    @Published public var selectedMode: LockMode = .cleaning
    @Published public var allDisplays = true
    @Published public var maximizeBrightness = true
    @Published public var autoUnlockSeconds: TimeInterval? = 60
    @Published public var selectiveConfiguration = SelectiveLockConfiguration()

    @Published public private(set) var sessionState: LockSessionState = .idle
    @Published public private(set) var secondsRemaining: Int?
    @Published public private(set) var warningMessage: String?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var permissionSettingsDestination: PermissionSettingsDestination?

    private let inputBlocker: any InputBlocking
    private let hidBlocker: any HIDDeviceBlocking
    private let overlays: any OverlayControlling
    private let brightness: any BrightnessControlling

    private var countdownTask: Task<Void, Never>?
    private var autoUnlockTask: Task<Void, Never>?

    public convenience init() {
        self.init(
            inputBlocker: SystemInputBlocker(),
            hidBlocker: SystemHIDDeviceBlocker(),
            overlays: DisplayOverlayController(),
            brightness: SystemBrightnessController()
        )
    }

    public init(
        inputBlocker: any InputBlocking,
        hidBlocker: any HIDDeviceBlocking,
        overlays: any OverlayControlling,
        brightness: any BrightnessControlling
    ) {
        self.inputBlocker = inputBlocker
        self.hidBlocker = hidBlocker
        self.overlays = overlays
        self.brightness = brightness
    }

    public var isActive: Bool {
        sessionState == .active
    }

    public var statusTitle: String {
        switch sessionState {
        case .idle:
            "Ready"
        case .countingDown(let seconds):
            "Starting in \(seconds)…"
        case .active:
            "Locked"
        }
    }

    public var brightnessSupportSummary: String {
        switch brightness.supportedDisplayCount {
        case 0: "Brightness unchanged"
        case 1: "1 supported display"
        default: "\(brightness.supportedDisplayCount) supported displays"
        }
    }

    public func startSelectedMode() {
        guard sessionState == .idle else {
            present(error: CleanMyScreenError.alreadyActive)
            return
        }

        if selectedMode == .selective, !selectiveConfiguration.hasSelection {
            present(error: CleanMyScreenError.noSelectiveInputChosen)
            return
        }

        clearMessages()

        // Ask before the countdown so a missing permission never makes the
        // user wait through an animation that cannot complete successfully.
        guard inputBlocker.requestMonitoringAccess() else {
            present(error: CleanMyScreenError.inputMonitoringRequired)
            return
        }

        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for seconds in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                self.sessionState = .countingDown(seconds)
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            self.beginSession()
        }
    }

    public func cancelCountdown() {
        guard case .countingDown = sessionState else { return }
        countdownTask?.cancel()
        countdownTask = nil
        sessionState = .idle
    }

    public func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        autoUnlockTask?.cancel()
        autoUnlockTask = nil
        secondsRemaining = nil

        inputBlocker.stop()
        hidBlocker.stop()
        overlays.hideAll()
        brightness.restore()
        sessionState = .idle
    }

    public func dismissError() {
        errorMessage = nil
        permissionSettingsDestination = nil
    }

    public func clearWarning() {
        warningMessage = nil
    }

    private func beginSession() {
        do {
            var eventMask: InputBlockMask = []
            var isUsingDeviceSpecificLock = false

            switch selectedMode {
            case .cleaning:
                eventMask = .all
            case .petKid:
                eventMask = [.keyboard, .pointer, .scrolling, .gestures]
            case .selective:
                if selectiveConfiguration.keyboard {
                    eventMask.insert(.keyboard)
                }

                if selectiveConfiguration.trackpad {
                    let count = try hidBlocker.blockBuiltInTrackpads()
                    guard count > 0 else { throw CleanMyScreenError.trackpadUnavailable }
                    isUsingDeviceSpecificLock = true
                }

                if selectiveConfiguration.externalDevices {
                    let count = try hidBlocker.blockExternalInputDevices()
                    guard count > 0 else { throw CleanMyScreenError.externalDevicesUnavailable }
                    isUsingDeviceSpecificLock = true
                }
            }

            if eventMask.isEmpty, isUsingDeviceSpecificLock {
                eventMask.insert(.emergencyUnlockOnly)
            }

            if !eventMask.isEmpty {
                try inputBlocker.start(blocking: eventMask) { [weak self] in
                    Task { @MainActor in
                        self?.stop()
                    }
                }
            }

            switch selectedMode {
            case .cleaning:
                if maximizeBrightness {
                    brightness.maximizeSupportedDisplays()
                    if brightness.supportedDisplayCount == 0 {
                        warningMessage = "No connected display exposes software brightness control; current brightness is unchanged."
                    }
                }
                overlays.showCleaningOverlay(
                    onAllDisplays: allDisplays,
                    unlockHint: "Hold Esc for 3 seconds to unlock"
                )
            case .petKid:
                overlays.showTransientHUD(
                    title: "Inputs locked",
                    detail: "Video and sound stay active · Hold Esc for 3 seconds to unlock"
                )
            case .selective:
                let names = hidBlocker.blockedDeviceNames
                let detail = names.isEmpty ? "Selected inputs are locked" : names.joined(separator: " · ")
                overlays.showTransientHUD(title: "Selective lock active", detail: detail)

                let failures = hidBlocker.failedDeviceNames
                if !failures.isEmpty {
                    warningMessage = "Some devices remain available: \(failures.joined(separator: ", "))."
                }
            }

            sessionState = .active
            scheduleAutomaticUnlock()
        } catch {
            inputBlocker.stop()
            hidBlocker.stop()
            overlays.hideAll()
            brightness.restore()
            sessionState = .idle
            present(error: error)
        }
    }

    private func scheduleAutomaticUnlock() {
        let configuredDuration: TimeInterval?
        if selectedMode == .selective,
           selectiveConfiguration.externalDevices,
           autoUnlockSeconds == nil {
            configuredDuration = 60
            warningMessage = "External-device sessions keep a 60-second safety timeout when Auto Unlock is off."
        } else {
            configuredDuration = autoUnlockSeconds
        }

        guard let duration = configuredDuration, duration.isFinite, duration > 0 else {
            secondsRemaining = nil
            if let configuredDuration, !configuredDuration.isFinite {
                warningMessage = "Auto Unlock was disabled because its duration was invalid."
            }
            return
        }

        let safeDuration = min(duration, 86_400)

        autoUnlockTask?.cancel()
        autoUnlockTask = Task { [weak self] in
            guard let self else { return }
            var remaining = Int(safeDuration.rounded(.up))
            self.secondsRemaining = remaining

            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remaining -= 1
                self.secondsRemaining = remaining
            }

            if !Task.isCancelled {
                self.stop()
            }
        }
    }

    private func clearMessages() {
        warningMessage = nil
        errorMessage = nil
        permissionSettingsDestination = nil
    }

    private func present(error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        permissionSettingsDestination = switch error as? CleanMyScreenError {
        case .inputMonitoringRequired:
            .inputMonitoring
        case .inputTapUnavailable:
            .accessibility
        default:
            nil
        }
    }
}
