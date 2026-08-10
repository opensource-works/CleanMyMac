import CleanMyScreenKit
import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.08, green: 0.42, blue: 0.93)
    static let accentPressed = Color(red: 0.05, green: 0.32, blue: 0.76)
    static let accentSoft = Color(red: 0.91, green: 0.95, blue: 1.00)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let subtleBackground = Color(nsColor: .underPageBackgroundColor)
    static let hairline = Color.primary.opacity(0.12)
    static let quietText = Color.secondary
    static let warning = Color(red: 0.83, green: 0.47, blue: 0.04)
    static let destructive = Color(red: 0.86, green: 0.20, blue: 0.20)

    static let outerPadding: CGFloat = 30
    static let contentWidth: CGFloat = 780
    static let cornerRadius: CGFloat = 13
}

struct AppCardModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
    }
}

extension View {
    func appCard(radius: CGFloat = AppTheme.cornerRadius) -> some View {
        modifier(AppCardModifier(radius: radius))
    }
}

extension LockSessionState {
    var isIdle: Bool {
        self == .idle
    }

    var isCountingDown: Bool {
        if case .countingDown = self {
            return true
        }
        return false
    }

    var countdownValue: Int? {
        if case .countingDown(let value) = self {
            return value
        }
        return nil
    }
}
