import Foundation

public enum LockSessionState: Equatable, Sendable {
    case idle
    case countingDown(Int)
    case active

    public var isBusy: Bool {
        self != .idle
    }
}
