import AppKit

/// Owns the windows used to cover displays during cleaning and to briefly show
/// lock-state information without obscuring the user's content.
@MainActor
public final class DisplayOverlayController: NSObject, OverlayControlling {
    private struct CleaningRequest {
        let allDisplays: Bool
        let unlockHint: String
    }

    private var cleaningRequest: CleaningRequest?
    private var cleaningWindows: [NSWindow] = []
    private var hintViews: [NSView] = []
    private var transientHUDWindow: NSWindow?
    private var hintFadeTimer: Timer?
    private var hudDismissTimer: Timer?
    private var hudCloseTimer: Timer?
    private var cursorIsHidden = false

    public var isShowingCleaningOverlay: Bool {
        cleaningRequest != nil
    }

    public override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    isolated deinit {
        hintFadeTimer?.invalidate()
        hudDismissTimer?.invalidate()
        hudCloseTimer?.invalidate()
        closeCleaningWindows()
        dismissTransientHUD()

        if cursorIsHidden {
            NSCursor.unhide()
        }

        // Removing the selector observer can retain a temporary reference to
        // self, so keep it as the final operation in an isolated deinitializer.
        NotificationCenter.default.removeObserver(self)
    }

    public func showCleaningOverlay(onAllDisplays: Bool, unlockHint: String) {
        dismissTransientHUD()
        closeCleaningWindows()

        cleaningRequest = CleaningRequest(
            allDisplays: onAllDisplays,
            unlockHint: unlockHint
        )
        rebuildCleaningWindows()

        if !cursorIsHidden {
            NSCursor.hide()
            cursorIsHidden = true
        }
    }

    public func showTransientHUD(title: String, detail: String) {
        hideAll()

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let panelSize = NSSize(width: 520, height: 104)
        let panelOrigin = NSPoint(
            x: screen.visibleFrame.midX - panelSize.width / 2,
            y: screen.visibleFrame.maxY - panelSize.height - 44
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: panelOrigin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        configureOverlayWindow(panel, capturesMouse: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        let contentView = makeHUDContentView(title: title, detail: detail)
        panel.contentView = contentView
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        transientHUDWindow = panel
        hudDismissTimer = Timer.scheduledTimer(
            timeInterval: 3.5,
            target: self,
            selector: #selector(beginHUDDismissal(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    public func hideAll() {
        hintFadeTimer?.invalidate()
        hintFadeTimer = nil
        hudDismissTimer?.invalidate()
        hudDismissTimer = nil
        hudCloseTimer?.invalidate()
        hudCloseTimer = nil

        cleaningRequest = nil
        closeCleaningWindows()
        dismissTransientHUD()

        if cursorIsHidden {
            NSCursor.unhide()
            cursorIsHidden = false
        }
    }

    @objc
    private func screenParametersDidChange(_ notification: Notification) {
        guard cleaningRequest != nil else { return }
        rebuildCleaningWindows()
    }

    private func rebuildCleaningWindows() {
        guard let request = cleaningRequest else { return }

        hintFadeTimer?.invalidate()
        hintFadeTimer = nil
        closeCleaningWindows()

        let screens: [NSScreen]
        if request.allDisplays {
            screens = NSScreen.screens
        } else if let mainScreen = NSScreen.main ?? NSScreen.screens.first {
            screens = [mainScreen]
        } else {
            screens = []
        }

        for screen in screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            configureOverlayWindow(window, capturesMouse: true)
            window.backgroundColor = .black
            window.isOpaque = true
            window.setFrame(screen.frame, display: true)

            let rootView = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            rootView.autoresizingMask = [.width, .height]
            rootView.wantsLayer = true
            rootView.layer?.backgroundColor = NSColor.black.cgColor

            let hintView = makeCleaningHintView(text: request.unlockHint)
            rootView.addSubview(hintView)
            NSLayoutConstraint.activate([
                hintView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
                hintView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -64),
                hintView.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
                hintView.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),
            ])

            window.contentView = rootView
            window.orderFrontRegardless()
            cleaningWindows.append(window)
            hintViews.append(hintView)
        }

        guard !hintViews.isEmpty else { return }
        hintFadeTimer = Timer.scheduledTimer(
            timeInterval: 2.75,
            target: self,
            selector: #selector(beginHintFade(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    private func configureOverlayWindow(_ window: NSWindow, capturesMouse: Bool) {
        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.screenSaverWindow))
        )
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.canHide = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = !capturesMouse
        window.animationBehavior = .none
    }

    private func makeCleaningHintView(text: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.13).cgColor
        container.layer?.cornerRadius = 14

        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = NSColor.white.withAlphaComponent(0.92)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 22),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -22),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 13),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -13),
        ])
        return container
    }

    private func makeHUDContentView(title: String, detail: String) -> NSView {
        let container = NSVisualEffectView()
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = NSColor.white.withAlphaComponent(0.76)
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.distribution = .fill
        stack.spacing = 6
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    @objc
    private func beginHintFade(_ timer: Timer) {
        hintFadeTimer = nil
        let views = hintViews
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for view in views {
                view.animator().alphaValue = 0
            }
        }
    }

    @objc
    private func beginHUDDismissal(_ timer: Timer) {
        hudDismissTimer = nil
        guard let window = transientHUDWindow else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            window.animator().alphaValue = 0
        }
        hudCloseTimer = Timer.scheduledTimer(
            timeInterval: 0.27,
            target: self,
            selector: #selector(finishHUDDismissal(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    @objc
    private func finishHUDDismissal(_ timer: Timer) {
        hudCloseTimer = nil
        transientHUDWindow?.orderOut(nil)
        transientHUDWindow?.close()
        transientHUDWindow = nil
    }

    private func closeCleaningWindows() {
        for window in cleaningWindows {
            window.orderOut(nil)
            window.close()
        }
        cleaningWindows.removeAll(keepingCapacity: true)
        hintViews.removeAll(keepingCapacity: true)
    }

    private func dismissTransientHUD() {
        hudDismissTimer?.invalidate()
        hudDismissTimer = nil
        hudCloseTimer?.invalidate()
        hudCloseTimer = nil
        transientHUDWindow?.orderOut(nil)
        transientHUDWindow?.close()
        transientHUDWindow = nil
    }
}
