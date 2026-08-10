import CleanMyScreenKit
import Foundation
import SwiftUI

struct ModeContentView: View {
    @EnvironmentObject private var coordinator: LockSessionCoordinator

    var body: some View {
        VStack(spacing: 22) {
            ModeHero(
                mode: coordinator.selectedMode,
                statusTitle: coordinator.statusTitle,
                countdown: coordinator.sessionState.countdownValue,
                isActive: coordinator.isActive
            )

            configurationControls
                .disabled(!coordinator.sessionState.isIdle)
                .opacity(coordinator.sessionState.isIdle ? 1 : 0.62)

            SessionActionView()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var configurationControls: some View {
        switch coordinator.selectedMode {
        case .cleaning:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    ToggleConfigurationCard(
                        title: "All Displays",
                        systemImage: "display.2",
                        isOn: $coordinator.allDisplays
                    )
                    ToggleConfigurationCard(
                        title: "Max Brightness",
                        systemImage: "sun.max",
                        isOn: $coordinator.maximizeBrightness
                    )
                    AutoUnlockConfigurationCard(seconds: $coordinator.autoUnlockSeconds)
                }

                VStack(spacing: 10) {
                    ToggleConfigurationCard(
                        title: "All Displays",
                        systemImage: "display.2",
                        isOn: $coordinator.allDisplays
                    )
                    ToggleConfigurationCard(
                        title: "Max Brightness",
                        systemImage: "sun.max",
                        isOn: $coordinator.maximizeBrightness
                    )
                    AutoUnlockConfigurationCard(seconds: $coordinator.autoUnlockSeconds)
                }
            }

        case .petKid:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    LockedFeatureCard(title: "Keyboard", systemImage: "keyboard")
                    LockedFeatureCard(title: "Trackpad", systemImage: "hand.point.up.left.fill")
                    AutoUnlockConfigurationCard(seconds: $coordinator.autoUnlockSeconds)
                }

                VStack(spacing: 10) {
                    LockedFeatureCard(title: "Keyboard", systemImage: "keyboard")
                    LockedFeatureCard(title: "Trackpad", systemImage: "hand.point.up.left.fill")
                    AutoUnlockConfigurationCard(seconds: $coordinator.autoUnlockSeconds)
                }
            }

        case .selective:
            VStack(spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        SelectiveToggleCard(
                            title: "Keyboard",
                            subtitle: "Keys and shortcuts",
                            systemImage: "keyboard",
                            keyPath: \.keyboard
                        )
                        SelectiveToggleCard(
                            title: "Trackpad",
                            subtitle: "Built-in trackpad",
                            systemImage: "hand.point.up.left.fill",
                            keyPath: \.trackpad
                        )
                        SelectiveToggleCard(
                            title: "External",
                            subtitle: "Compatible devices · Experimental",
                            systemImage: "externaldrive.fill",
                            keyPath: \.externalDevices
                        )
                    }

                    VStack(spacing: 10) {
                        SelectiveToggleCard(
                            title: "Keyboard",
                            subtitle: "Keys and shortcuts",
                            systemImage: "keyboard",
                            keyPath: \.keyboard
                        )
                        SelectiveToggleCard(
                            title: "Trackpad",
                            subtitle: "Built-in trackpad",
                            systemImage: "hand.point.up.left.fill",
                            keyPath: \.trackpad
                        )
                        SelectiveToggleCard(
                            title: "External",
                            subtitle: "Compatible devices · Experimental",
                            systemImage: "externaldrive.fill",
                            keyPath: \.externalDevices
                        )
                    }
                }

                AutoUnlockConfigurationCard(seconds: $coordinator.autoUnlockSeconds)
                    .frame(maxWidth: 260)
            }
        }
    }
}

private struct ModeHero: View {
    let mode: LockMode
    let statusTitle: String
    let countdown: Int?
    let isActive: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(isActive ? Color.green : countdown == nil ? AppTheme.accent : AppTheme.warning)
                    .frame(width: 7, height: 7)
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.045), in: Capsule())

            Text(heroTitle)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(heroSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            DevicePreview(mode: mode, countdown: countdown, isActive: isActive)
                .padding(.top, 5)
        }
    }

    private var heroTitle: String {
        if let countdown {
            return "Starting in \(countdown)…"
        }
        if isActive {
            return switch mode {
            case .cleaning: "Cleaning mode is active"
            case .petKid: "Pet / Kid mode is active"
            case .selective: "Selected inputs are locked"
            }
        } else {
            return switch mode {
            case .cleaning: "Ready to clean"
            case .petKid: "Ready for worry-free viewing"
            case .selective: "Choose what to lock"
            }
        }
    }

    private var heroSubtitle: String {
        switch mode {
        case .cleaning:
            "Black screens  ·  Full brightness  ·  All input locked"
        case .petKid:
            "Video and sound keep playing  ·  Keyboard and trackpad locked"
        case .selective:
            "Lock only the inputs you choose  ·  Everything else stays available"
        }
    }
}

private struct DevicePreview: View {
    let mode: LockMode
    let countdown: Int?
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.black)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 8)
                    }

                screenContent
                    .padding(11)

                if let countdown {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.72))
                            .frame(width: 82, height: 82)
                        Text("\(countdown)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 390, height: 218)
            .shadow(color: .black.opacity(0.18), radius: 12, y: 8)

            Rectangle()
                .fill(Color(nsColor: .systemGray))
                .frame(width: 82, height: 34)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black.opacity(0.18))
                        .frame(height: 1)
                }

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(nsColor: .lightGray))
                .frame(width: 120, height: 7)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
        }
        .frame(height: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewAccessibilityLabel)
    }

    @ViewBuilder
    private var screenContent: some View {
        switch mode {
        case .cleaning:
            Color.black

        case .petKid:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.13, blue: 0.20))
                VStack(spacing: 13) {
                    Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 55))
                        .foregroundStyle(AppTheme.accent)
                    Text(isActive ? "Playing safely" : "Your video stays visible")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

        case .selective:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                HStack(spacing: 30) {
                    SelectivePreviewSymbol(systemImage: "keyboard")
                    SelectivePreviewSymbol(systemImage: "hand.point.up.left.fill")
                    SelectivePreviewSymbol(systemImage: "externaldrive.fill")
                }
            }
        }
    }

    private var previewAccessibilityLabel: String {
        switch mode {
        case .cleaning: "Preview of a black screen for cleaning mode"
        case .petKid: "Preview showing video remains visible in Pet and Kid mode"
        case .selective: "Preview of keyboard, trackpad, and external device locks"
        }
    }
}

private struct SelectivePreviewSymbol: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 29, weight: .medium))
            .foregroundStyle(.white.opacity(0.88))
            .frame(width: 56, height: 56)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ToggleConfigurationCard: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 11) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, minHeight: 55)
        .appCard()
    }
}

private struct LockedFeatureCard: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accentSoft, in: Circle())
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, minHeight: 55)
        .appCard()
    }
}

private struct AutoUnlockConfigurationCard: View {
    @Binding var seconds: TimeInterval?

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
            Text("Auto Unlock")
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 6)
            Picker("Auto Unlock", selection: $seconds) {
                Text("Off").tag(Optional<TimeInterval>.none)
                Text("30 sec").tag(Optional<TimeInterval>.some(30))
                Text("60 sec").tag(Optional<TimeInterval>.some(60))
                Text("2 min").tag(Optional<TimeInterval>.some(120))
                Text("5 min").tag(Optional<TimeInterval>.some(300))
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, minHeight: 55)
        .appCard()
    }
}

private struct SelectiveToggleCard: View {
    @EnvironmentObject private var coordinator: LockSessionCoordinator

    let title: String
    let subtitle: String
    let systemImage: String
    let keyPath: WritableKeyPath<SelectiveLockConfiguration, Bool>

    private var isOn: Binding<Bool> {
        Binding(
            get: { coordinator.selectiveConfiguration[keyPath: keyPath] },
            set: { value in
                var configuration = coordinator.selectiveConfiguration
                configuration[keyPath: keyPath] = value
                coordinator.selectiveConfiguration = configuration
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? AppTheme.accent : .secondary)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
        .background(
            isOn.wrappedValue ? AppTheme.accent.opacity(0.055) : AppTheme.cardBackground,
            in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(isOn.wrappedValue ? AppTheme.accent.opacity(0.35) : AppTheme.hairline, lineWidth: 1)
        }
    }
}

private struct SessionActionView: View {
    @EnvironmentObject private var coordinator: LockSessionCoordinator

    var body: some View {
        VStack(spacing: 10) {
            Button(action: performPrimaryAction) {
                HStack(spacing: 9) {
                    Image(systemName: actionIcon)
                    Text(actionTitle)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(actionColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 330)
            .keyboardShortcut(.return, modifiers: [.command])

            if let secondsRemaining = coordinator.secondsRemaining {
                Text("Automatically unlocking in \(formattedDuration(secondsRemaining))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if coordinator.isActive {
                Text("Automatic unlock is off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if coordinator.selectedMode == .selective,
                      !coordinator.selectiveConfiguration.hasSelection {
                Label("Select at least one input", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }
        }
    }

    private var actionTitle: String {
        switch coordinator.sessionState {
        case .idle:
            switch coordinator.selectedMode {
            case .cleaning: "Start Cleaning"
            case .petKid: "Start Pet / Kid Mode"
            case .selective: "Start Selective Lock"
            }
        case .countingDown(let seconds):
            "Cancel · Starting in \(seconds)"
        case .active:
            "Unlock Now"
        }
    }

    private var actionIcon: String {
        switch coordinator.sessionState {
        case .idle: "lock.fill"
        case .countingDown: "xmark"
        case .active: "lock.open.fill"
        }
    }

    private var actionColor: Color {
        switch coordinator.sessionState {
        case .idle: AppTheme.accent
        case .countingDown: AppTheme.warning
        case .active: AppTheme.destructive
        }
    }

    private func performPrimaryAction() {
        switch coordinator.sessionState {
        case .idle:
            coordinator.startSelectedMode()
        case .countingDown:
            coordinator.cancelCountdown()
        case .active:
            coordinator.stop()
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes > 0 ? "\(minutes):\(String(format: "%02d", remainder))" : "\(seconds)s"
    }
}
