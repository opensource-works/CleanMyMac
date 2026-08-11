import Foundation

public enum LockMode: String, CaseIterable, Identifiable, Sendable {
    case cleaning
    case petKid
    case selective

    public var id: Self { self }

    public var title: String {
        switch self {
        case .cleaning: "Cleaning"
        case .petKid: "Pet / Kid"
        case .selective: "Selective"
        }
    }

    public var systemImage: String {
        switch self {
        case .cleaning: "sparkles"
        case .petKid: "pawprint.fill"
        case .selective: "lock.square"
        }
    }

    /// Viewing modes should hand the foreground back to the content the user
    /// wants to watch. Cleaning keeps its own window because the display is
    /// immediately covered by the cleaning overlay.
    public var hidesApplicationOnActivation: Bool {
        self != .cleaning
    }

    public var hidesApplicationWhenCountdownBegins: Bool {
        self == .petKid
    }

    public var countdownSeconds: Int {
        switch self {
        case .petKid: 5
        case .cleaning, .selective: 3
        }
    }
}
