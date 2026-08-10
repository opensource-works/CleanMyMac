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
}
