import AppKit
import CleanMyScreenKit
import SwiftUI

@MainActor
private final class CleanMyScreenApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var coordinator: LockSessionCoordinator?

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}

@main
struct CleanMyScreenApp: App {
    @NSApplicationDelegateAdaptor(CleanMyScreenApplicationDelegate.self)
    private var applicationDelegate

    @StateObject private var coordinator = LockSessionCoordinator()

    var body: some Scene {
        WindowGroup("CleanMyScreen", id: "main") {
            ContentView()
                .environmentObject(coordinator)
                .tint(AppTheme.accent)
                .frame(minWidth: 760, minHeight: 670)
                .background(AppTheme.windowBackground)
                .onAppear {
                    applicationDelegate.coordinator = coordinator
                }
        }
        .defaultSize(width: 920, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("Session") {
                Button("Start \(coordinator.selectedMode.title) Mode") {
                    coordinator.startSelectedMode()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!coordinator.sessionState.isIdle)

                Button("Cancel Countdown") {
                    coordinator.cancelCountdown()
                }
                .disabled(!coordinator.sessionState.isCountingDown)

                Button("Unlock Now") {
                    coordinator.stop()
                }
                .keyboardShortcut(.escape, modifiers: [.command])
                .disabled(!coordinator.isActive)
            }
        }

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(coordinator)
        } label: {
            Image(systemName: coordinator.isActive ? "lock.fill" : "sparkles")
                .accessibilityLabel(coordinator.isActive ? "CleanMyScreen locked" : "CleanMyScreen ready")
        }
        .menuBarExtraStyle(.menu)
    }
}
