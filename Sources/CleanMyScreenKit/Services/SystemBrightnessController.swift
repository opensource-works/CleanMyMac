import CoreGraphics
import Darwin
import Foundation

/// Best-effort software brightness control for displays supported by
/// CoreDisplay. Unsupported displays are deliberately ignored.
@MainActor
public final class SystemBrightnessController: BrightnessControlling {
    private typealias GetBrightnessFunction = @convention(c) (
        CGDirectDisplayID,
        UnsafeMutablePointer<Float>
    ) -> Int32
    private typealias SetBrightnessFunction = @convention(c) (
        CGDirectDisplayID,
        Float
    ) -> Int32

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var getBrightnessFunction: GetBrightnessFunction?
    private var setBrightnessFunction: SetBrightnessFunction?
    private var originalBrightness: [CGDirectDisplayID: Float] = [:]

    public var supportedDisplayCount: Int {
        guard let getBrightnessFunction else { return 0 }

        return onlineDisplayIDs().reduce(into: 0) { count, displayID in
            var brightness: Float = 0
            guard getBrightnessFunction(displayID, &brightness) == 0,
                  brightness.isFinite,
                  (0 ... 1).contains(brightness)
            else {
                return
            }
            count += 1
        }
    }

    public init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/CoreDisplay.framework/CoreDisplay"
        guard let handle = dlopen(frameworkPath, RTLD_LAZY | RTLD_LOCAL) else {
            return
        }

        guard let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
              let setSymbol = dlsym(handle, "DisplayServicesSetBrightness")
        else {
            dlclose(handle)
            return
        }

        frameworkHandle = handle
        getBrightnessFunction = unsafeBitCast(
            getSymbol,
            to: GetBrightnessFunction.self
        )
        setBrightnessFunction = unsafeBitCast(
            setSymbol,
            to: SetBrightnessFunction.self
        )
    }

    isolated deinit {
        restore()
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    public func maximizeSupportedDisplays() {
        guard let getBrightnessFunction, let setBrightnessFunction else { return }

        for displayID in onlineDisplayIDs() {
            var currentBrightness: Float = 0
            guard getBrightnessFunction(displayID, &currentBrightness) == 0,
                  currentBrightness.isFinite,
                  (0 ... 1).contains(currentBrightness)
            else {
                continue
            }

            if originalBrightness[displayID] == nil {
                originalBrightness[displayID] = currentBrightness
            }

            // A non-zero result simply means this particular display is not
            // controllable. No error is propagated and other displays remain
            // eligible for adjustment.
            _ = setBrightnessFunction(displayID, 1)
        }
    }

    public func restore() {
        guard let setBrightnessFunction else {
            originalBrightness.removeAll()
            return
        }

        let savedBrightness = originalBrightness
        originalBrightness.removeAll()

        for (displayID, brightness) in savedBrightness {
            guard brightness.isFinite, (0 ... 1).contains(brightness) else { continue }
            _ = setBrightnessFunction(displayID, brightness)
        }
    }

    private func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success,
              displayCount > 0
        else {
            return []
        }

        var displayIDs = [CGDirectDisplayID](
            repeating: CGDirectDisplayID(),
            count: Int(displayCount)
        )
        var populatedCount = displayCount
        guard CGGetOnlineDisplayList(
            displayCount,
            &displayIDs,
            &populatedCount
        ) == .success else {
            return []
        }

        return Array(displayIDs.prefix(Int(populatedCount)))
    }
}
