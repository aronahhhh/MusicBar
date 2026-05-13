import AppKit
import Combine
import SwiftUI

final class StatusBarController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let controlPopover = NSPopover()
    private let nowPlayingService: NowPlayingService
    private let lyricsService = LyricsService()
    private let settings = AppSettings()
    private var menuBarIslandView: NSHostingView<MenuBarIslandView>?
    private var settingsWindow: NSWindow?
    private var lyricsWindow: NSWindow?
    private var controlPopoverCloseWorkItem: DispatchWorkItem?
    private var isMouseInsideControlPopover = false
    private var hoverTrackingTimer: Timer?
    private var popoverLocalEventMonitor: Any?
    private var popoverGlobalEventMonitor: Any?
    private var isAutoLyricsWindowVisible = false
    private var cancellables = Set<AnyCancellable>()

    init(nowPlayingService: NowPlayingService) {
        self.nowPlayingService = nowPlayingService
        super.init()
        configureStatusItem()
        configurePopover()
        configureControlPopover()
        bind()
    }

    deinit {
        hoverTrackingTimer?.invalidate()
        stopMainPopoverEventMonitoring()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        statusItem.length = 104
        button.image = nil
        button.title = ""
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let hostingView = HoverTrackingHostingView(
            rootView: MenuBarIslandView(service: nowPlayingService),
            onMouseEntered: { [weak self] in self?.showControlPopover() },
            onMouseExited: { [weak self] in self?.hideControlPopover() }
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setFrameSize(button.bounds.size)
        button.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        menuBarIslandView = hostingView
        startHoverTrackingTimer()
    }

    private func configurePopover() {
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentSize = NSSize(width: 176, height: 200)
        popover.contentViewController = NSHostingController(
            rootView: ActionPopoverView(
                onLyrics: { [weak self] in self?.showLyricsWindow() },
                onSettings: { [weak self] in self?.showSettings() },
                onUpdate: { [weak self] in self?.openUpdatePage() },
                onGitHub: { [weak self] in self?.openGitHub() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }

    private func configureControlPopover() {
        controlPopover.behavior = .transient
        controlPopover.animates = true
        controlPopover.contentSize = NSSize(width: 300, height: 92)
        controlPopover.contentViewController = NSHostingController(
            rootView: HoverPlaybackControlsView(
                nowPlayingService: nowPlayingService,
                onMouseEntered: { [weak self] in self?.keepControlPopoverOpen() },
                onMouseExited: { [weak self] in self?.scheduleControlPopoverClose() }
            )
        )
    }

    private func bind() {
        nowPlayingService.$track
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                self?.renderStatusItem(track)
            }
            .store(in: &cancellables)
    }

    private func renderStatusItem(_ track: TrackInfo?) {
        guard let button = statusItem.button else {
            return
        }

        if let track {
            statusItem.length = 212
            button.toolTip = "\(track.displayTitle) - \(track.displayArtist)"
            if lyricsWindow?.isVisible == true {
                lyricsService.loadLyrics(for: track)
            }
            syncAutoLyricsWindow(for: track)
        } else {
            statusItem.length = 104
            button.toolTip = "No music playing"
            syncAutoLyricsWindow(for: nil)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            closeMainPopover()
        } else {
            closeControlPopoverImmediately()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startMainPopoverEventMonitoring()
        }
    }

    private func closeMainPopover() {
        stopMainPopoverEventMonitoring()
        popover.performClose(nil)
    }

    private func startMainPopoverEventMonitoring() {
        stopMainPopoverEventMonitoring()

        popoverLocalEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else {
                return event
            }

            let popoverWindow = self.popover.contentViewController?.view.window
            let statusWindow = self.statusItem.button?.window

            if event.window == popoverWindow || event.window == statusWindow {
                return event
            }

            self.closeMainPopover()
            return event
        }

        popoverGlobalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeMainPopover()
        }
    }

    private func stopMainPopoverEventMonitoring() {
        if let popoverLocalEventMonitor {
            NSEvent.removeMonitor(popoverLocalEventMonitor)
            self.popoverLocalEventMonitor = nil
        }

        if let popoverGlobalEventMonitor {
            NSEvent.removeMonitor(popoverGlobalEventMonitor)
            self.popoverGlobalEventMonitor = nil
        }
    }

    private func showControlPopover() {
        guard let button = statusItem.button,
              nowPlayingService.track != nil,
              !popover.isShown,
              lyricsWindow?.isKeyWindow != true else {
            return
        }

        if !controlPopover.isShown {
            controlPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        controlPopoverCloseWorkItem?.cancel()
        controlPopoverCloseWorkItem = nil
    }

    private func hideControlPopover() {
        scheduleControlPopoverClose()
    }

    private func keepControlPopoverOpen() {
        isMouseInsideControlPopover = true
        controlPopoverCloseWorkItem?.cancel()
        controlPopoverCloseWorkItem = nil
    }

    private func scheduleControlPopoverClose() {
        isMouseInsideControlPopover = false
        controlPopoverCloseWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  !self.isMouseInsideControlPopover,
                  !self.isMouseInsideHoverControlArea() else {
                return
            }

            self.controlPopover.performClose(nil)
        }
        controlPopoverCloseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    private func closeControlPopoverImmediately() {
        controlPopoverCloseWorkItem?.cancel()
        controlPopoverCloseWorkItem = nil
        controlPopover.performClose(nil)
    }

    private func startHoverTrackingTimer() {
        hoverTrackingTimer?.invalidate()
        hoverTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            self?.updateHoverControlVisibility()
        }
        hoverTrackingTimer?.tolerance = 0.04
    }

    private func updateHoverControlVisibility() {
        guard nowPlayingService.track != nil else {
            closeControlPopoverImmediately()
            return
        }

        if isMouseInsideHoverControlArea() {
            showControlPopover()
        } else if controlPopover.isShown {
            scheduleControlPopoverClose()
        }
    }

    private func isMouseInsideHoverControlArea() -> Bool {
        let mouseLocation = NSEvent.mouseLocation

        if let buttonFrame = statusButtonScreenFrame(),
           buttonFrame.insetBy(dx: -8, dy: -8).contains(mouseLocation) {
            return true
        }

        if let popoverFrame = controlPopover.contentViewController?.view.window?.frame,
           popoverFrame.insetBy(dx: -10, dy: -10).contains(mouseLocation) {
            return true
        }

        return false
    }

    private func statusButtonScreenFrame() -> NSRect? {
        guard let button = statusItem.button,
              let window = button.window else {
            return nil
        }

        let frameInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }

    private func showLyricsWindow(activate: Bool = true, closeMenu: Bool = true) {
        if closeMenu {
            closeMainPopover()
        }

        if let track = nowPlayingService.track {
            lyricsService.loadLyrics(for: track)
        }

        if let lyricsWindow {
            if activate || !lyricsWindow.isVisible {
                lyricsWindow.makeKeyAndOrderFront(nil)
            }
            if activate {
                NSApp.activate(ignoringOtherApps: true)
            }
            if !activate {
                isAutoLyricsWindowVisible = true
            }
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 220, height: 180)
        if !window.setFrameUsingName("MusicBarLyricsWindow") {
            window.center()
        }
        window.setFrameAutosaveName("MusicBarLyricsWindow")
        window.title = "Lyrics"
        window.delegate = self
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.alphaValue = 1
        window.level = .normal
        window.contentViewController = NSHostingController(
            rootView: LyricsWindowView(
                service: lyricsService,
                nowPlayingService: nowPlayingService,
                settings: settings,
                onOpacityChanged: { [weak window] opacity in
                    window?.alphaValue = max(0.18, opacity)
                }
            )
        )
        window.isReleasedWhenClosed = false
        lyricsWindow = window

        if AppEdition.supportsLyricsWindowOpacity {
            settings.$lyricsWindowOpacity
                .receive(on: RunLoop.main)
                .sink { [weak window] opacity in
                    window?.alphaValue = max(0.18, opacity)
                }
                .store(in: &cancellables)
        }

        if AppEdition.supportsLyricsWindowPinning {
            settings.$lyricsWindowAlwaysOnTop
                .receive(on: RunLoop.main)
                .sink { [weak window] alwaysOnTop in
                    window?.level = alwaysOnTop ? .floating : .normal
                }
                .store(in: &cancellables)
        }

        window.makeKeyAndOrderFront(nil)
        isAutoLyricsWindowVisible = !activate
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func hideLyricsWindow() {
        isAutoLyricsWindowVisible = false
        lyricsWindow?.orderOut(nil)
    }

    private func syncAutoLyricsWindow(for track: TrackInfo?) {
        guard AppEdition.supportsAutoLyricsWindow, settings.autoShowLyricsWindow else {
            return
        }

        if track?.state == .playing {
            if let track {
                lyricsService.loadLyrics(for: track)
            }
            if lyricsWindow?.isVisible != true || isAutoLyricsWindowVisible {
                showLyricsWindow(activate: false, closeMenu: false)
            }
        } else {
            if isAutoLyricsWindowVisible {
                hideLyricsWindow()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as AnyObject? === lyricsWindow {
            isAutoLyricsWindowVisible = false
        } else if notification.object as AnyObject? === settingsWindow {
            settingsWindow = nil
        }
    }

    private func showSettings() {
        closeMainPopover()

        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: settingsWindowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MusicBar Settings"
        window.contentViewController = NSHostingController(rootView: SettingsView(settings: settings))
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openUpdatePage() {
        closeMainPopover()
        NSWorkspace.shared.open(settings.releasesURL)
    }

    private func openGitHub() {
        closeMainPopover()
        NSWorkspace.shared.open(settings.githubURL)
    }

    private var settingsWindowHeight: CGFloat {
        AppEdition.supportsAutoLyricsWindow || AppEdition.supportsLaunchAtLogin ? 218 : 162
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private final class HoverTrackingHostingView<Content: View>: NSHostingView<Content> {
    private let onMouseEntered: () -> Void
    private let onMouseExited: () -> Void
    private var trackingAreaRef: NSTrackingArea?

    init(rootView: Content, onMouseEntered: @escaping () -> Void, onMouseExited: @escaping () -> Void) {
        self.onMouseEntered = onMouseEntered
        self.onMouseExited = onMouseExited
        super.init(rootView: rootView)
    }

    @MainActor required init(rootView: Content) {
        self.onMouseEntered = {}
        self.onMouseExited = {}
        super.init(rootView: rootView)
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
