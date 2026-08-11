import AppKit
import CleanMyScreenKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: LockSessionCoordinator

    private var isPresentingError: Binding<Bool> {
        Binding(
            get: { coordinator.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    coordinator.dismissError()
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 26) {
                        ModeSelector(
                            selection: $coordinator.selectedMode,
                            isEnabled: coordinator.sessionState.isIdle
                        )
                        .id("mode-selector")

                        ModeContentView {
                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollProxy.scrollTo("mode-selector", anchor: .top)
                            }
                        }

                        if let warning = coordinator.warningMessage {
                            MessageBanner(
                                message: warning,
                                systemImage: "exclamationmark.triangle.fill",
                                tint: AppTheme.warning,
                                dismiss: coordinator.clearWarning
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: AppTheme.contentWidth)
                    .padding(.horizontal, AppTheme.outerPadding)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.never)
            }

            SafetyExitFooter()
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.selectedMode)
        .animation(.easeInOut(duration: 0.2), value: coordinator.warningMessage)
        .onChange(of: coordinator.sessionState) { _, state in
            let shouldHide = switch state {
            case .idle:
                false
            case .countingDown:
                coordinator.selectedMode.hidesApplicationWhenCountdownBegins
            case .active:
                coordinator.selectedMode.hidesApplicationOnActivation
            }

            guard shouldHide else { return }

            // The app must keep running to enforce the lock, so hide it instead
            // of terminating it. The menu-bar item remains available.
            NSApp.hide(nil)
        }
        .alert("CleanMyScreen couldn’t start", isPresented: isPresentingError) {
            if let destination = coordinator.permissionSettingsDestination {
                Button(settingsButtonTitle(for: destination)) {
                    openPermissionSettings(destination)
                    coordinator.dismissError()
                }
                Button("Cancel", role: .cancel) {
                    coordinator.dismissError()
                }
            } else {
                Button("OK", role: .cancel) {
                    coordinator.dismissError()
                }
            }
        } message: {
            Text(coordinator.errorMessage ?? "Please try again.")
        }
    }

    private func settingsButtonTitle(for destination: PermissionSettingsDestination) -> String {
        switch destination {
        case .inputMonitoring:
            "Open Input Monitoring Settings"
        case .accessibility:
            "Open Accessibility Settings"
        }
    }

    private func openPermissionSettings(_ destination: PermissionSettingsDestination) {
        let urlString = switch destination {
        case .inputMonitoring:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        case .accessibility:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }

        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct ModeSelector: View {
    @Binding var selection: LockMode
    let isEnabled: Bool

    @State private var hoveredMode: LockMode?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(LockMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                        .font(.system(size: 15, weight: selection == mode ? .semibold : .medium))
                        .foregroundStyle(selection == mode ? Color.white : Color.primary.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(background(for: mode))
                }
                .onHover { isHovering in
                    hoveredMode = isHovering ? mode : nil
                }
                .disabled(!isEnabled)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(maxWidth: 590)
        .appCard(radius: 12)
        .opacity(isEnabled ? 1 : 0.78)
    }

    private func background(for mode: LockMode) -> Color {
        if selection == mode {
            return AppTheme.accent
        }
        if hoveredMode == mode, isEnabled {
            return Color.primary.opacity(0.06)
        }
        return .clear
    }
}

private struct MessageBanner: View {
    let message: String
    let systemImage: String
    let tint: Color
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss message")
        }
        .padding(13)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct SafetyExitFooter: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 9) {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(.secondary)
                Text("Hold")
                UnlockKeycap("esc", width: 34)
                Text("for 3 seconds to unlock")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground.opacity(0.72))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hold Escape for 3 seconds to unlock")
        }
    }
}

private struct UnlockKeycap: View {
    let label: String
    let width: CGFloat

    init(_ label: String, width: CGFloat = 25) {
        self.label = label
        self.width = width
    }

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(width: width, height: 21)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var coordinator: LockSessionCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(coordinator.statusTitle)

        if let secondsRemaining = coordinator.secondsRemaining {
            Text("Automatic unlock in \(formattedDuration(secondsRemaining))")
        }

        Divider()

        Menu("Mode: \(coordinator.selectedMode.title)") {
            ForEach(LockMode.allCases) { mode in
                Button {
                    coordinator.selectedMode = mode
                } label: {
                    if coordinator.selectedMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
                .disabled(!coordinator.sessionState.isIdle)
            }
        }

        switch coordinator.sessionState {
        case .idle:
            Button("Start \(coordinator.selectedMode.title) Mode") {
                coordinator.startSelectedMode()
            }
        case .countingDown(let seconds):
            Button("Cancel — Starting in \(seconds)") {
                coordinator.cancelCountdown()
            }
        case .active:
            Button("Unlock Now") {
                coordinator.stop()
            }
        }

        Divider()

        Button("Open CleanMyScreen") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit CleanMyScreen") {
            coordinator.stop()
            NSApp.terminate(nil)
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes > 0 ? "\(minutes):\(String(format: "%02d", remainder))" : "\(seconds)s"
    }
}
