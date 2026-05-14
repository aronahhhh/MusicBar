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
    private let license = AppLicense()
    private var menuBarIslandView: NSHostingView<MenuBarIslandView>?
    private var settingsWindow: NSWindow?
    private var lyricsWindow: NSWindow?
    private var purchaseWindow: NSWindow?
    private var controlPopoverCloseWorkItem: DispatchWorkItem?
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
            rootView: MenuBarIslandView(service: nowPlayingService, settings: settings),
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
        popover.contentSize = NSSize(width: 156, height: 92)
        popover.contentViewController = NSHostingController(
            rootView: ActionPopoverView(
                onSettings: { [weak self] in self?.showSettings() },
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

        settings.$showNowPlayingInMenuBar
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.renderStatusItem(self?.nowPlayingService.track)
            }
            .store(in: &cancellables)
    }

    private func renderStatusItem(_ track: TrackInfo?) {
        guard let button = statusItem.button else {
            return
        }

        if let track {
            statusItem.length = settings.showNowPlayingInMenuBar ? 212 : 104
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
              license.isEntitled,
              settings.showHoverPlaybackControls,
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
        controlPopoverCloseWorkItem?.cancel()
        controlPopoverCloseWorkItem = nil
    }

    private func scheduleControlPopoverClose() {
        guard controlPopoverCloseWorkItem == nil else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.controlPopoverCloseWorkItem = nil

            guard !self.isMouseInsideHoverControlArea() else {
                return
            }

            self.controlPopover.performClose(nil)
        }
        controlPopoverCloseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
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

        guard license.isEntitled else {
            closeControlPopoverImmediately()
            return
        }

        guard settings.showHoverPlaybackControls else {
            closeControlPopoverImmediately()
            return
        }

        if controlPopover.isShown {
            if isMouseInsideHoverControlArea() {
                controlPopoverCloseWorkItem?.cancel()
                controlPopoverCloseWorkItem = nil
            } else {
                scheduleControlPopoverClose()
            }
        } else if isMouseInsideStatusButtonTriggerArea() {
            showControlPopover()
        }
    }

    private func isMouseInsideStatusButtonTriggerArea() -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        guard let buttonFrame = statusButtonScreenFrame() else {
            return false
        }

        return buttonFrame.insetBy(dx: -1, dy: 0).contains(mouseLocation)
    }

    private func isMouseInsideHoverControlArea() -> Bool {
        let mouseLocation = NSEvent.mouseLocation

        if let buttonFrame = statusButtonScreenFrame(),
           buttonFrame.insetBy(dx: -4, dy: -2).contains(mouseLocation) {
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

        guard license.isEntitled else {
            showPurchaseWindow()
            return
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
            .environmentObject(settings)
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
        guard license.isEntitled, AppEdition.supportsAutoLyricsWindow, settings.autoShowLyricsWindow else {
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
        } else if notification.object as AnyObject? === purchaseWindow {
            purchaseWindow = nil
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
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 530),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MusicBar Settings"
        window.contentViewController = NSHostingController(
            rootView: SettingsView(
                settings: settings,
                license: license,
                onPurchase: { [weak self] in self?.openPurchasePage() },
                onGitHub: { [weak self] in self?.openGitHub() },
                onUpdate: { [weak self] in self?.openUpdatePage() }
            )
        )
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

    private func openPurchasePage() {
        NSWorkspace.shared.open(license.purchaseURL)
    }

    private func showPurchaseWindow() {
        closeMainPopover()

        if let purchaseWindow {
            purchaseWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MusicBar Trial"
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: PurchaseView(
                license: license,
                text: SettingsText(languageCode: settings.appLanguage.resolvedCode),
                onPurchase: { [weak self] in self?.openPurchasePage() },
                onClose: { [weak window] in window?.close() }
            )
        )
        window.isReleasedWhenClosed = false
        purchaseWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
