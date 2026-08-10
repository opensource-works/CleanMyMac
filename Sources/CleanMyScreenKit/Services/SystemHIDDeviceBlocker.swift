import CoreGraphics
import Foundation
import IOKit.hid

/// Exclusively opens selected HID devices for the lifetime of a lock session.
/// Devices that macOS refuses to seize are skipped so one unavailable device
/// does not prevent the remaining compatible devices from being locked.
public final class SystemHIDDeviceBlocker: HIDDeviceBlocking, @unchecked Sendable {
    private struct SeizedDevice {
        let device: IOHIDDevice
        let name: String
        let registryEntryID: UInt64?
    }

    private let stateLock = NSLock()
    private var seizedDevices: [SeizedDevice] = []
    private var failedNames: [String] = []

    public init() {}

    deinit {
        stop()
    }

    public var blockedDeviceNames: [String] {
        stateLock.lock()
        defer { stateLock.unlock() }
        var seenNames: Set<String> = []
        return seizedDevices.map(\.name).filter { seenNames.insert($0).inserted }
    }

    public var failedDeviceNames: [String] {
        stateLock.lock()
        defer { stateLock.unlock() }
        var seenNames: Set<String> = []
        return failedNames.filter { seenNames.insert($0).inserted }
    }

    @discardableResult
    public func blockBuiltInTrackpads() throws -> Int {
        try seizeDevices(matching: .builtInTrackpad)
    }

    @discardableResult
    public func blockExternalInputDevices() throws -> Int {
        try seizeDevices(matching: .externalInput)
    }

    public func stop() {
        stateLock.lock()
        // Closing every successfully seized device restores normal event-system
        // ownership. Close in reverse order to mirror acquisition.
        for item in seizedDevices.reversed() {
            IOHIDDeviceClose(item.device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        seizedDevices.removeAll(keepingCapacity: false)
        failedNames.removeAll(keepingCapacity: false)
        stateLock.unlock()
    }

    private func seizeDevices(matching target: HIDBlockTarget) throws -> Int {
        guard CGPreflightListenEventAccess() || CGRequestListenEventAccess() else {
            throw CleanMyScreenError.inputMonitoringRequired
        }

        let devices = Self.discoverDevices()
        let candidates = devices.map { device in
            (device: device, profile: Self.profile(for: device))
        }
        let reservedEmergencyKeyboard: IOHIDDevice?
        switch target {
        case .externalInput:
            let hasBuiltInKeyboard = candidates.contains {
                $0.profile.isBuiltIn && $0.profile.isKeyboard
            }
            reservedEmergencyKeyboard = hasBuiltInKeyboard ? nil : candidates.first {
                !$0.profile.isBuiltIn && $0.profile.isKeyboard
            }?.device
        case .builtInTrackpad:
            reservedEmergencyKeyboard = nil
        }
        var blockedCount = 0

        stateLock.lock()
        defer { stateLock.unlock() }

        for (device, profile) in candidates {
            guard target.matches(profile) else { continue }

            if let reservedEmergencyKeyboard,
               CFEqual(reservedEmergencyKeyboard, device) {
                failedNames.append("\(profile.displayName) (kept available for emergency unlock)")
                continue
            }

            let registryEntryID = Self.registryEntryID(for: device)
            guard !isAlreadySeized(device, registryEntryID: registryEntryID) else {
                continue
            }

            let result = IOHIDDeviceOpen(
                device,
                IOOptionBits(kIOHIDOptionsTypeSeizeDevice)
            )
            guard result == kIOReturnSuccess else {
                failedNames.append(profile.displayName)
                continue
            }

            seizedDevices.append(
                SeizedDevice(
                    device: device,
                    name: profile.displayName,
                    registryEntryID: registryEntryID
                )
            )
            blockedCount += 1
        }

        return blockedCount
    }

    private func isAlreadySeized(_ device: IOHIDDevice, registryEntryID: UInt64?) -> Bool {
        seizedDevices.contains { existing in
            if let registryEntryID, let existingID = existing.registryEntryID {
                return registryEntryID == existingID
            }
            return CFEqual(existing.device, device)
        }
    }

    private static func discoverDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        IOHIDManagerSetDeviceMatching(manager, nil)

        // Copying the manager's synchronously enumerated set does not require
        // opening every device first. This lets each candidate be opened once,
        // directly with the exclusive option below.
        guard let deviceSet = IOHIDManagerCopyDevices(manager) else {
            return []
        }
        return (deviceSet as Set).map { $0 as! IOHIDDevice }
    }

    private static func profile(for device: IOHIDDevice) -> HIDDeviceProfile {
        let name = stringProperty(kIOHIDProductKey, of: device)
            ?? stringProperty(kIOHIDManufacturerKey, of: device)
            ?? "HID input device"
        let transport = stringProperty(kIOHIDTransportKey, of: device) ?? ""
        let explicitlyBuiltIn = booleanProperty(kIOHIDBuiltInKey, of: device)
        let transportLooksBuiltIn = {
            let normalized = transport.lowercased()
            return normalized.contains("spi")
                || normalized.contains("embedded")
                || normalized.contains("internal")
        }()
        let nameLooksBuiltIn = {
            let normalized = name.lowercased()
            return normalized.contains("internal")
                || normalized.contains("built-in")
                || normalized.contains("built in")
        }()

        let conformsToKeyboard = IOHIDDeviceConformsTo(
            device,
            UInt32(kHIDPage_GenericDesktop),
            UInt32(kHIDUsage_GD_Keyboard)
        )
        let conformsToMouse = IOHIDDeviceConformsTo(
            device,
            UInt32(kHIDPage_GenericDesktop),
            UInt32(kHIDUsage_GD_Mouse)
        )
        let conformsToPointer = IOHIDDeviceConformsTo(
            device,
            UInt32(kHIDPage_GenericDesktop),
            UInt32(kHIDUsage_GD_Pointer)
        )
        let conformsToTouchpad = IOHIDDeviceConformsTo(
            device,
            UInt32(kHIDPage_Digitizer),
            UInt32(kHIDUsage_Dig_TouchPad)
        )

        return HIDDeviceProfile(
            name: name,
            isBuiltIn: explicitlyBuiltIn ?? (transportLooksBuiltIn || nameLooksBuiltIn),
            isKeyboard: conformsToKeyboard,
            isPointer: conformsToMouse || conformsToPointer,
            isTouchpad: conformsToTouchpad
        )
    }

    private static func registryEntryID(for device: IOHIDDevice) -> UInt64? {
        let service = IOHIDDeviceGetService(device)
        guard service != MACH_PORT_NULL else { return nil }

        var identifier: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &identifier) == kIOReturnSuccess else {
            return nil
        }
        return identifier
    }

    private static func stringProperty(
        _ key: String,
        of device: IOHIDDevice
    ) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private static func booleanProperty(
        _ key: String,
        of device: IOHIDDevice
    ) -> Bool? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }

        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean))
        }
        if CFGetTypeID(value) == CFNumberGetTypeID() {
            return (value as? NSNumber)?.boolValue
        }
        return nil
    }
}

enum HIDBlockTarget: Sendable {
    case builtInTrackpad
    case externalInput

    func matches(_ profile: HIDDeviceProfile) -> Bool {
        switch self {
        case .builtInTrackpad:
            // Some Apple trackpads expose a pointer collection and identify
            // themselves by product name rather than Touch Pad usage.
            let nameLooksLikeTrackpad = profile.name.localizedCaseInsensitiveContains("trackpad")
                || profile.name.localizedCaseInsensitiveContains("touchpad")
                || profile.name.localizedCaseInsensitiveContains("multi-touch")
                || profile.name.localizedCaseInsensitiveContains("multitouch")
            return profile.isBuiltIn
                && (profile.isTouchpad || (profile.isPointer && nameLooksLikeTrackpad))

        case .externalInput:
            return !profile.isBuiltIn
                && (profile.isKeyboard || profile.isPointer || profile.isTouchpad)
        }
    }
}

struct HIDDeviceProfile: Sendable, Equatable {
    let name: String
    let isBuiltIn: Bool
    let isKeyboard: Bool
    let isPointer: Bool
    let isTouchpad: Bool

    var displayName: String {
        if name.isEmpty {
            return isBuiltIn && isTouchpad ? "Built-in trackpad" : "HID input device"
        }
        return name
    }
}
