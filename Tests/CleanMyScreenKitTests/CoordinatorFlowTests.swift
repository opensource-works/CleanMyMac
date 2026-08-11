import Foundation
import Testing
@testable import CleanMyScreenKit

@MainActor
@Test("Input Monitoring is checked before the countdown starts")
func permissionIsCheckedBeforeCountdown() {
    let input = TestInputBlocker(hasMonitoringAccess: false)
    let coordinator = LockSessionCoordinator(
        inputBlocker: input,
        hidBlocker: TestHIDBlocker(),
        overlays: TestOverlayController(),
        brightness: TestBrightnessController()
    )

    coordinator.startSelectedMode()

    #expect(input.monitoringRequestCount == 1)
    #expect(coordinator.sessionState == .idle)
    #expect(coordinator.permissionSettingsDestination == .inputMonitoring)
}

@MainActor
@Test("Granted Input Monitoring begins the countdown")
func permissionAllowsCountdown() async {
    let input = TestInputBlocker(hasMonitoringAccess: true)
    let coordinator = LockSessionCoordinator(
        inputBlocker: input,
        hidBlocker: TestHIDBlocker(),
        overlays: TestOverlayController(),
        brightness: TestBrightnessController()
    )

    coordinator.startSelectedMode()
    await Task.yield()

    #expect(input.monitoringRequestCount == 1)
    #expect(coordinator.sessionState == .countingDown(3))
    coordinator.cancelCountdown()
}

private final class TestInputBlocker: InputBlocking, @unchecked Sendable {
    let hasMonitoringAccess: Bool
    private(set) var monitoringRequestCount = 0
    var isRunning = false

    init(hasMonitoringAccess: Bool) {
        self.hasMonitoringAccess = hasMonitoringAccess
    }

    func requestMonitoringAccess() -> Bool {
        monitoringRequestCount += 1
        return hasMonitoringAccess
    }

    func start(
        blocking mask: InputBlockMask,
        onEmergencyUnlock: @escaping @Sendable () -> Void
    ) throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}

private final class TestHIDBlocker: HIDDeviceBlocking, @unchecked Sendable {
    var blockedDeviceNames: [String] = []
    var failedDeviceNames: [String] = []

    func blockBuiltInTrackpads() throws -> Int { 1 }
    func blockExternalInputDevices() throws -> Int { 1 }
    func stop() {}
}

@MainActor
private final class TestOverlayController: OverlayControlling {
    var isShowingCleaningOverlay = false

    func showCleaningOverlay(onAllDisplays: Bool, unlockHint: String) {
        isShowingCleaningOverlay = true
    }

    func showTransientHUD(title: String, detail: String) {}

    func hideAll() {
        isShowingCleaningOverlay = false
    }
}

@MainActor
private final class TestBrightnessController: BrightnessControlling {
    var supportedDisplayCount = 1
    func maximizeSupportedDisplays() {}
    func restore() {}
}
