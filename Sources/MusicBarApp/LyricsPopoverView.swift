import SwiftUI

struct LyricsWindowView: View {
    @ObservedObject var service: LyricsService
    @ObservedObject var nowPlayingService: NowPlayingService
    @ObservedObject var settings: AppSettings
    let onOpacityChanged: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let fullWindowSize = CGSize(
                width: geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing,
                height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            )

            LyricsDisplayView(
                service: service,
                nowPlayingService: nowPlayingService,
                showsControls: true,
                settings: settings,
                windowSize: fullWindowSize,
                onOpacityChanged: onOpacityChanged
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

private struct LyricsDisplayView: View {
    @ObservedObject var service: LyricsService
    @ObservedObject var nowPlayingService: NowPlayingService
    let showsControls: Bool
    @ObservedObject var settings: AppSettings
    let windowSize: CGSize
    var onOpacityChanged: (Double) -> Void = { _ in }
    @State private var showsOpacityPanel = false
    @State private var opacityPanelCloseToken = UUID()
    @State private var showsPlaybackControls = true
    @State private var playbackControlsHideToken = UUID()
    @State private var hostingWindow: NSWindow?

    var body: some View {
        ZStack(alignment: .bottom) {
            LyricsBackgroundView(settings: settings, windowSize: windowSize)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(0)

            VStack(alignment: .leading, spacing: 14) {
                header

                content
            }
            .padding(showsControls ? 20 : 18)
            .zIndex(1)

            if showsControls && showsPlaybackControls {
                playbackControlsOverlay
                    .zIndex(10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.22), value: showsPlaybackControls)
        .onAppear {
            schedulePlaybackControlsHide()
        }
        .onHover { hovering in
            guard showsControls else {
                return
            }

            withAnimation(.easeInOut(duration: 0.18)) {
                showsPlaybackControls = hovering
            }

            if hovering {
                schedulePlaybackControlsHide()
            }
        }
        .onContinuousHover { phase in
            guard showsControls else {
                return
            }

            switch phase {
            case .active:
                revealPlaybackControls()
            case .ended:
                schedulePlaybackControlsHide(after: 0.35)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    revealPlaybackControls()
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    revealPlaybackControls()
                }
        )
        .background(
            LyricsWindowAccessor { window in
                if hostingWindow !== window {
                    hostingWindow = window
                }
            }
        )
    }

    private var playbackControlsOverlay: some View {
        PlaybackControlsView(
            nowPlayingService: nowPlayingService,
            compact: false,
            onScrubBegan: disableWindowBackgroundDragging,
            onScrubFinished: restoreWindowBackgroundDragging
        )
            .frame(maxWidth: 268)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .center)
            .allowsHitTesting(true)
    }

    private func disableWindowBackgroundDragging() {
        hostingWindow?.isMovableByWindowBackground = false
    }

    private func restoreWindowBackgroundDragging() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            hostingWindow?.isMovableByWindowBackground = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let track = nowPlayingService.track {
                ArtworkView(path: track.artworkPath, cornerRadius: 8, refreshID: track.updatedAt)
                    .frame(width: showsControls ? 42 : 32, height: showsControls ? 42 : 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.displayTitle)
                        .font(.system(size: showsControls ? 15 : 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                    Text(track.displayArtist)
                        .font(.system(size: showsControls ? 12 : 11, weight: .medium, design: .rounded))
                        .foregroundStyle(titleColor.opacity(0.58))
                        .lineLimit(1)
                }
            } else {
                Text("Lyrics")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(titleColor)
            }

            Spacer(minLength: 0)

            if showsControls,
               AppEdition.supportsLyricsWindowPinning || AppEdition.supportsLyricsWindowOpacity {
                lyricsWindowControls(settings: settings, onOpacityChanged: onOpacityChanged)
            }
        }
    }

    private var titleColor: Color {
        switch settings.lyricsTextColorMode {
        case .white:
            return .white
        case .black:
            return .black
        case .custom:
            return Color(hex: settings.lyricsCustomTextColorHex)
        }
    }

    private var content: some View {
        Group {
            switch service.state {
            case .idle, .loading:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading lyrics...")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case let .loaded(title, artist, lines, isSynced):
                AppleMusicLyricsLinesView(
                    lines: lines,
                    isSynced: isSynced,
                    track: nowPlayingService.track,
                    nowPlayingService: nowPlayingService,
                    large: showsControls,
                    fallbackTitle: title,
                    fallbackArtist: artist,
                    onInteraction: revealPlaybackControls
                )

            case let .unavailable(message):
                VStack(spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(message)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func lyricsWindowControls(settings: AppSettings, onOpacityChanged: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            if AppEdition.supportsLyricsWindowPinning {
                Button {
                    settings.lyricsWindowAlwaysOnTop.toggle()
                } label: {
                    Image(systemName: settings.lyricsWindowAlwaysOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(settings.lyricsWindowAlwaysOnTop ? .white : .white.opacity(0.65))
                        .background(.black.opacity(0.62), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Keep the lyrics window above other windows")
            }

            if AppEdition.supportsLyricsWindowOpacity {
                Button {
                    showsOpacityPanel.toggle()
                    scheduleOpacityPanelClose()
                } label: {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.white.opacity(0.78))
                        .background(.black.opacity(0.62), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showsOpacityPanel, arrowEdge: .bottom) {
                    OpacityPanel(
                        settings: settings,
                        onOpacityChanged: onOpacityChanged,
                        onInteraction: scheduleOpacityPanelClose
                    )
                }
                .help("Adjust lyrics window opacity")
            }
        }
    }

    private func scheduleOpacityPanelClose() {
        let token = UUID()
        opacityPanelCloseToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            guard opacityPanelCloseToken == token else {
                return
            }

            withAnimation(.easeInOut(duration: 0.16)) {
                showsOpacityPanel = false
            }
        }
    }

    private func schedulePlaybackControlsHide(after delay: TimeInterval = 2.6) {
        guard showsControls else {
            return
        }

        let token = UUID()
        playbackControlsHideToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard playbackControlsHideToken == token else {
                return
            }

            withAnimation(.easeInOut(duration: 0.24)) {
                showsPlaybackControls = false
            }
        }
    }

    private func revealPlaybackControls() {
        guard showsControls else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            showsPlaybackControls = true
        }
        schedulePlaybackControlsHide()
    }
}

struct PlaybackControlsView: View {
    @ObservedObject var nowPlayingService: NowPlayingService
    let compact: Bool
    let onScrubBegan: () -> Void
    let onScrubFinished: () -> Void
    @State private var isScrubbing = false
    @State private var scrubPosition: TimeInterval = 0

    init(
        nowPlayingService: NowPlayingService,
        compact: Bool = false,
        onScrubBegan: @escaping () -> Void = {},
        onScrubFinished: @escaping () -> Void = {}
    ) {
        self.nowPlayingService = nowPlayingService
        self.compact = compact
        self.onScrubBegan = onScrubBegan
        self.onScrubFinished = onScrubFinished
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { timeline in
            let track = nowPlayingService.track
            let duration = max(track?.duration ?? 0, 0)
            let livePosition = clampedPosition(for: track, now: timeline.date)
            let sliderValue = isScrubbing ? scrubPosition : livePosition

            VStack(spacing: compact ? 8 : 8) {
                VStack(spacing: compact ? 5 : 6) {
                    ScrubProgressBar(
                        value: sliderValue,
                        duration: duration,
                        isDisabled: duration <= 0,
                        onScrubBegan: {
                            isScrubbing = true
                            onScrubBegan()
                        },
                        onScrubChanged: { position in
                            scrubPosition = position
                            isScrubbing = true
                        },
                        onScrubEnded: { position in
                            scrubPosition = position
                            nowPlayingService.seek(to: position)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                isScrubbing = false
                                onScrubFinished()
                            }
                        }
                    )
                    .frame(height: compact ? 20 : 16)

                    if !compact {
                        HStack {
                            Text(formatTime(sliderValue))
                            Spacer()
                            Text(duration > 0 ? "-\(formatTime(max(duration - sliderValue, 0)))" : "--:--")
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    }
                }

                HStack(spacing: compact ? 18 : 18) {
                    Button {
                        nowPlayingService.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: compact ? 15 : 16, weight: .bold))
                            .frame(width: compact ? 24 : 24, height: compact ? 24 : 24)
                            .background(selectionFill(nowPlayingService.isShuffleEnabled), in: Circle())
                    }

                    Button {
                        nowPlayingService.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: compact ? 20 : 23, weight: .bold))
                    }

                    Button {
                        nowPlayingService.togglePlayPause()
                    } label: {
                        Image(systemName: track?.state == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: compact ? 28 : 28, weight: .bold))
                            .frame(width: compact ? 36 : 36, height: compact ? 34 : 32)
                    }

                    Button {
                        nowPlayingService.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: compact ? 20 : 23, weight: .bold))
                    }

                    Button {
                        nowPlayingService.toggleRepeat()
                    } label: {
                        Image(systemName: "repeat")
                            .font(.system(size: compact ? 15 : 16, weight: .bold))
                            .frame(width: compact ? 24 : 24, height: compact ? 24 : 24)
                            .background(selectionFill(nowPlayingService.isRepeatEnabled), in: Circle())
                    }
                }
                .buttonStyle(AppleMusicControlButtonStyle())
                .foregroundStyle(.white.opacity(track == nil ? 0.32 : 0.86))
                .disabled(track == nil)

                if !compact {
                    HStack(spacing: 12) {
                        VolumeControl(nowPlayingService: nowPlayingService)
                        OutputDeviceMenu(nowPlayingService: nowPlayingService)
                    }
                    .padding(.top, 1)
                }
            }
            .padding(.top, compact ? 0 : 6)
        }
    }

    private func selectionFill(_ selected: Bool) -> Color {
        selected ? .white.opacity(0.3) : .white.opacity(0.12)
    }

    private func clampedPosition(for track: TrackInfo?, now: Date) -> TimeInterval {
        guard let track, let position = track.position else {
            return 0
        }

        let duration = track.duration ?? .greatestFiniteMagnitude
        let livePosition = track.state == .playing ? position + now.timeIntervalSince(track.updatedAt) : position
        return min(max(livePosition, 0), duration)
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite else {
            return "--:--"
        }

        let totalSeconds = max(0, Int(value.rounded()))
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}

private struct AppleMusicControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct LyricsBackgroundView: View {
    @ObservedObject var settings: AppSettings
    let windowSize: CGSize
    @State private var image: NSImage?
    @State private var loadedPath = ""

    var body: some View {
        ZStack {
            if settings.lyricsBackgroundMode == .image, let image {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: safeWindowSize.width, height: safeWindowSize.height)
                    .blur(radius: min(settings.lyricsBackgroundBlur, 8))
            } else {
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Color.black.opacity(settings.lyricsBackgroundDim)
        }
        .frame(width: safeWindowSize.width, height: safeWindowSize.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear(perform: loadImageIfNeeded)
        .onChange(of: settings.lyricsBackgroundImagePath) { _ in
            loadImageIfNeeded()
        }
        .onChange(of: settings.lyricsBackgroundMode) { _ in
            loadImageIfNeeded()
        }
    }

    private var safeWindowSize: CGSize {
        CGSize(width: max(windowSize.width, 1), height: max(windowSize.height, 1))
    }

    private var backgroundColors: [Color] {
        if settings.lyricsBackgroundMode == .custom {
            return [Color(hex: settings.lyricsCustomBackgroundColorHex), Color.black.opacity(0.85)]
        }

        switch settings.lyricsBackgroundMode {
        case .midnight:
            return [Color.black.opacity(0.94), Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.96)]
        case .graphite:
            return [Color(red: 0.13, green: 0.14, blue: 0.16), Color(red: 0.02, green: 0.02, blue: 0.03)]
        case .ivory:
            return [Color(red: 0.95, green: 0.92, blue: 0.84), Color(red: 0.62, green: 0.56, blue: 0.46)]
        case .custom:
            return [Color(hex: settings.lyricsCustomBackgroundColorHex), Color.black.opacity(0.85)]
        case .image:
            return [Color.black, Color.black.opacity(0.8)]
        }
    }

    private func loadImageIfNeeded() {
        let path = settings.lyricsBackgroundImagePath
        guard settings.lyricsBackgroundMode == .image, !path.isEmpty else {
            image = nil
            loadedPath = ""
            return
        }

        guard path != loadedPath else {
            return
        }

        loadedPath = path
        image = NSImage(contentsOfFile: path)
    }
}

private struct VolumeControl: View {
    @ObservedObject var nowPlayingService: NowPlayingService
    @State private var localVolume: Double = 100

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.68))

            Slider(
                value: Binding(
                    get: { localVolume },
                    set: { value in
                        localVolume = value
                        nowPlayingService.setSoundVolume(Int(value.rounded()))
                    }
                ),
                in: 0...100
            )
            .frame(width: 78)
        }
        .onAppear {
            localVolume = Double(nowPlayingService.volume)
        }
        .onChange(of: nowPlayingService.volume) { volume in
            localVolume = Double(volume)
        }
    }
}

private struct OutputDeviceMenu: View {
    @ObservedObject var nowPlayingService: NowPlayingService

    var body: some View {
        Menu {
            if nowPlayingService.outputDevices.isEmpty {
                Text("No output devices")
            } else {
                ForEach(nowPlayingService.outputDevices) { device in
                    Button {
                        nowPlayingService.setOutputDevice(device.id)
                    } label: {
                        Label(device.displayName, systemImage: device.isDefault ? "checkmark.circle.fill" : "speaker.wave.2")
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 11, weight: .semibold))
                Text(selectedDeviceTitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(.white.opacity(0.12), in: Capsule(style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var selectedDeviceTitle: String {
        nowPlayingService.outputDevices.first(where: \.isDefault)?.name ?? "Output"
    }
}

private struct LyricsWindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

private struct ScrollWheelActivityMonitor: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughScrollMonitorView()
        context.coordinator.view = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScroll = onScroll
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var onScroll: (CGFloat) -> Void
        weak var view: NSView?
        private var monitor: Any?

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
        }

        func installMonitor() {
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, self.isEventInsideView(event) else {
                    return event
                }

                self.onScroll(event.scrollingDeltaY)
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func isEventInsideView(_ event: NSEvent) -> Bool {
            guard let view, event.window === view.window else {
                return false
            }

            let point = view.convert(event.locationInWindow, from: nil)
            return view.bounds.contains(point)
        }
    }
}

private final class PassthroughScrollMonitorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private struct ScrubProgressBar: View {
    let value: TimeInterval
    let duration: TimeInterval
    let isDisabled: Bool
    let onScrubBegan: () -> Void
    let onScrubChanged: (TimeInterval) -> Void
    let onScrubEnded: (TimeInterval) -> Void
    @State private var hasStartedDrag = false

    var body: some View {
        GeometryReader { geometry in
            let progress = duration > 0 ? min(max(value / duration, 0), 1) : 0

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.26))
                    .frame(height: 7)

                Capsule(style: .continuous)
                    .fill(.white.opacity(0.9))
                    .frame(width: geometry.size.width * progress, height: 7)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(
                ScrubGestureCaptureView(
                    duration: duration,
                    isDisabled: isDisabled,
                    onScrubBegan: {
                        guard !hasStartedDrag else {
                            return
                        }

                        hasStartedDrag = true
                        onScrubBegan()
                    },
                    onScrubChanged: onScrubChanged,
                    onScrubEnded: { position in
                        hasStartedDrag = false
                        onScrubEnded(position)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            .opacity(isDisabled ? 0.42 : 1)
        }
    }

    private func position(for x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0, duration > 0 else {
            return 0
        }

        let progress = min(max(x / width, 0), 1)
        return duration * TimeInterval(progress)
    }
}

private struct ScrubGestureCaptureView: NSViewRepresentable {
    let duration: TimeInterval
    let isDisabled: Bool
    let onScrubBegan: () -> Void
    let onScrubChanged: (TimeInterval) -> Void
    let onScrubEnded: (TimeInterval) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            duration: duration,
            isDisabled: isDisabled,
            onScrubBegan: onScrubBegan,
            onScrubChanged: onScrubChanged,
            onScrubEnded: onScrubEnded
        )
    }

    func makeNSView(context: Context) -> ScrubCaptureNSView {
        let view = ScrubCaptureNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ScrubCaptureNSView, context: Context) {
        context.coordinator.duration = duration
        context.coordinator.isDisabled = isDisabled
        context.coordinator.onScrubBegan = onScrubBegan
        context.coordinator.onScrubChanged = onScrubChanged
        context.coordinator.onScrubEnded = onScrubEnded
        nsView.coordinator = context.coordinator
    }

    final class Coordinator {
        var duration: TimeInterval
        var isDisabled: Bool
        var onScrubBegan: () -> Void
        var onScrubChanged: (TimeInterval) -> Void
        var onScrubEnded: (TimeInterval) -> Void
        var isDragging = false

        init(
            duration: TimeInterval,
            isDisabled: Bool,
            onScrubBegan: @escaping () -> Void,
            onScrubChanged: @escaping (TimeInterval) -> Void,
            onScrubEnded: @escaping (TimeInterval) -> Void
        ) {
            self.duration = duration
            self.isDisabled = isDisabled
            self.onScrubBegan = onScrubBegan
            self.onScrubChanged = onScrubChanged
            self.onScrubEnded = onScrubEnded
        }

        func beginScrub(at point: NSPoint, in bounds: NSRect) {
            guard !isDisabled, duration > 0 else {
                return
            }

            isDragging = true
            onScrubBegan()
            onScrubChanged(position(for: point.x, width: bounds.width))
        }

        func updateScrub(at point: NSPoint, in bounds: NSRect) {
            guard isDragging, !isDisabled, duration > 0 else {
                return
            }

            onScrubChanged(position(for: point.x, width: bounds.width))
        }

        func finishScrub(at point: NSPoint, in bounds: NSRect) {
            guard isDragging else {
                return
            }

            isDragging = false
            guard !isDisabled, duration > 0 else {
                return
            }

            onScrubEnded(position(for: point.x, width: bounds.width))
        }

        private func position(for x: CGFloat, width: CGFloat) -> TimeInterval {
            guard width > 0 else {
                return 0
            }

            let progress = min(max(x / width, 0), 1)
            return duration * TimeInterval(progress)
        }
    }
}

private final class ScrubCaptureNSView: NSView {
    weak var coordinator: ScrubGestureCaptureView.Coordinator?

    override var acceptsFirstResponder: Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        window?.isMovableByWindowBackground = false
        coordinator?.beginScrub(at: convert(event.locationInWindow, from: nil), in: bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        window?.isMovableByWindowBackground = false
        coordinator?.updateScrub(at: convert(event.locationInWindow, from: nil), in: bounds)
    }

    override func mouseUp(with event: NSEvent) {
        coordinator?.finishScrub(at: convert(event.locationInWindow, from: nil), in: bounds)
    }
}

private struct OpacityPanel: View {
    @ObservedObject var settings: AppSettings
    let onOpacityChanged: (Double) -> Void
    let onInteraction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Opacity")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(Int(settings.lyricsWindowOpacity * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { settings.lyricsWindowOpacity },
                    set: { value in
                        let nextOpacity = max(0.18, value)
                        settings.lyricsWindowOpacity = nextOpacity
                        onOpacityChanged(nextOpacity)
                        onInteraction()
                    }
                ),
                in: 0.18...1.0
            )
        }
        .padding(12)
        .frame(width: 190)
        .onAppear(perform: onInteraction)
    }
}

private struct AppleMusicLyricsLinesView: View {
    let lines: [LyricLine]
    let isSynced: Bool
    let track: TrackInfo?
    @ObservedObject var nowPlayingService: NowPlayingService
    let large: Bool
    let fallbackTitle: String
    let fallbackArtist: String
    let onInteraction: () -> Void
    @EnvironmentObject private var settings: AppSettings
    @State private var manualScrollUntil = Date.distantPast
    @State private var manualScrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let metrics = layoutMetrics(for: geometry.size)
            let textWidth = max(120, geometry.size.width - metrics.horizontalInset * 2)
            let viewportHeight = geometry.size.height
            let initialPosition = currentPosition(now: Date())
            let activeIndex = activeLineIndex(at: initialPosition)
            let contentHeight = contentHeight(currentIndex: activeIndex, textWidth: textWidth, metrics: metrics)
            let maxOffset = max((contentHeight - viewportHeight) / 2, 0)

            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                let currentIndex = activeLineIndex(at: currentPosition(now: timeline.date))
                let followsPlayback = Date() >= manualScrollUntil
                let automaticOffset = offset(for: currentIndex, viewportHeight: viewportHeight, contentHeight: contentHeight, textWidth: textWidth, metrics: metrics)
                let displayedOffset = followsPlayback ? automaticOffset : min(max(manualScrollOffset, -maxOffset), maxOffset)

                ZStack {
                    VStack(alignment: .center, spacing: metrics.rowSpacing) {
                        ForEach(lines) { line in
                            Text(line.text)
                                .font(.system(size: fontSize(for: line.id, currentIndex: currentIndex, metrics: metrics), weight: fontWeight(for: line.id, currentIndex: currentIndex), design: .rounded))
                                .foregroundStyle(color(for: line.id, currentIndex: currentIndex))
                                .multilineTextAlignment(.center)
                                .lineSpacing(metrics.internalLineSpacing)
                                .lineLimit(lineLimit(for: line.id, currentIndex: currentIndex, metrics: metrics))
                                .minimumScaleFactor(0.82)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: textWidth, height: estimatedLineHeight(for: line, currentIndex: currentIndex, textWidth: textWidth, metrics: metrics), alignment: .center)
                                .scaleEffect(line.id == currentIndex ? metrics.currentScale : 0.98)
                                .contentShape(Rectangle())
                                .modifier(LyricSeekModifier(
                                    line: line,
                                    isSynced: isSynced,
                                    nowPlayingService: nowPlayingService,
                                    onInteraction: onInteraction
                                ))
                                .animation(.easeInOut(duration: 0.18), value: currentIndex)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, metrics.verticalPadding)
                    .offset(y: displayedOffset)
                    .animation(followsPlayback ? .easeInOut(duration: 0.22) : nil, value: displayedOffset)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .background(
                    ScrollWheelActivityMonitor { delta in
                        manualScrollUntil = Date().addingTimeInterval(4.0)
                        manualScrollOffset = min(max(displayedOffset + delta, -maxOffset), maxOffset)
                        onInteraction()
                    }
                )
                .onChange(of: currentIndex) { _ in
                    if followsPlayback {
                        manualScrollOffset = automaticOffset
                    }
                }
            }
        }
    }

    private func layoutMetrics(for size: CGSize) -> LyricsLayoutMetrics {
        let widthFactor = min(max((size.width - 220) / 240, 0), 1)
        let heightFactor = min(max((size.height - 260) / 300, 0), 1)
        let comfort = min(widthFactor, heightFactor)
        let userFontScale = CGFloat(settings.lyricsFontScale)
        let userLineSpacing = CGFloat(settings.lyricsLineSpacing)
        let compactScale = 0.76 + comfort * 0.24

        return LyricsLayoutMetrics(
            currentFontSize: (large ? 21 + comfort * 3 : 18 + comfort * 2) * userFontScale * compactScale,
            secondaryFontSize: (large ? 15 + comfort * 3 : 13 + comfort * 2) * userFontScale * compactScale,
            rowSpacing: (large ? 3 + comfort * 5 : 2 + comfort * 4) * userLineSpacing,
            internalLineSpacing: large ? 0.5 + comfort : 0.25 + comfort * 0.75,
            verticalPadding: large ? 34 + comfort * 50 : 24 + comfort * 34,
            horizontalInset: large ? 18 + comfort * 9 : 14 + comfort * 6,
            minimumRowHeight: (large ? 21 + comfort * 7 : 18 + comfort * 5) * userFontScale,
            currentScale: 1 + comfort * 0.025,
            prefersTightCurrentLine: comfort < 0.28
        )
    }

    private func estimatedLineHeight(for line: LyricLine, currentIndex: Int?, textWidth: CGFloat, metrics: LyricsLayoutMetrics) -> CGFloat {
        let size = fontSize(for: line.id, currentIndex: currentIndex, metrics: metrics)
        let maxLines = lineLimit(for: line.id, currentIndex: currentIndex, metrics: metrics)
        let lineCount = estimatedWrappedLineCount(for: line.text, fontSize: size, textWidth: textWidth, maxLines: maxLines)
        let textHeight = CGFloat(lineCount) * size * (large ? 1.04 : 1.02)
        let verticalBreathingRoom = line.id == currentIndex ? size * 0.12 : size * 0.07
        return max(metrics.minimumRowHeight, textHeight + verticalBreathingRoom)
    }

    private func estimatedWrappedLineCount(for text: String, fontSize: CGFloat, textWidth: CGFloat, maxLines: Int) -> Int {
        guard textWidth > 0, !text.isEmpty else {
            return 1
        }

        let averageCharacterWidth = fontSize * (text.contains(where: { $0.isASCII }) ? 0.54 : 0.92)
        let estimatedWidth = CGFloat(text.count) * averageCharacterWidth
        return min(max(Int(ceil(estimatedWidth / textWidth)), 1), maxLines)
    }

    private func contentHeight(currentIndex: Int?, textWidth: CGFloat, metrics: LyricsLayoutMetrics) -> CGFloat {
        guard !lines.isEmpty else {
            return 0
        }

        let lineHeights = lines.map { estimatedLineHeight(for: $0, currentIndex: currentIndex, textWidth: textWidth, metrics: metrics) }
        let spacingTotal = CGFloat(max(lines.count - 1, 0)) * metrics.rowSpacing
        return metrics.verticalPadding * 2 + lineHeights.reduce(0, +) + spacingTotal
    }

    private func offset(for currentIndex: Int?, viewportHeight: CGFloat, contentHeight: CGFloat, textWidth: CGFloat, metrics: LyricsLayoutMetrics) -> CGFloat {
        guard let currentIndex else {
            return 0
        }

        let rowCenter = centerY(for: currentIndex, textWidth: textWidth, metrics: metrics)
        let centeredOffset = contentHeight / 2 - rowCenter
        let maxOffset = max((contentHeight - viewportHeight) / 2, 0)
        return min(max(centeredOffset, -maxOffset), maxOffset)
    }

    private func centerY(for id: Int, textWidth: CGFloat, metrics: LyricsLayoutMetrics) -> CGFloat {
        var y = metrics.verticalPadding
        for line in lines {
            let height = estimatedLineHeight(for: line, currentIndex: id, textWidth: textWidth, metrics: metrics)
            if line.id == id {
                return y + height / 2
            }
            y += height + metrics.rowSpacing
        }

        return y
    }

    private func fontSize(for id: Int, currentIndex: Int?, metrics: LyricsLayoutMetrics) -> CGFloat {
        guard isSynced, let currentIndex else {
            return metrics.secondaryFontSize
        }

        return id == currentIndex ? metrics.currentFontSize : metrics.secondaryFontSize
    }

    private func lineLimit(for id: Int, currentIndex: Int?, metrics: LyricsLayoutMetrics) -> Int {
        guard id == currentIndex else {
            return metrics.prefersTightCurrentLine ? 1 : 2
        }

        return metrics.prefersTightCurrentLine ? 2 : 3
    }

    private func fontWeight(for id: Int, currentIndex: Int?) -> Font.Weight {
        guard isSynced, let currentIndex else {
            return .semibold
        }

        return id == currentIndex ? .bold : .semibold
    }

    private func color(for id: Int, currentIndex: Int?) -> Color {
        let baseColor = lyricColor
        guard isSynced, let currentIndex else {
            return baseColor.opacity(0.9)
        }

        let distance = abs(id - currentIndex)
        if distance == 0 {
            return baseColor
        }
        if distance == 1 {
            return baseColor.opacity(0.45)
        }
        return baseColor.opacity(0.22)
    }

    private var lyricColor: Color {
        switch settings.lyricsTextColorMode {
        case .white:
            return .white
        case .black:
            return .black
        case .custom:
            return Color(hex: settings.lyricsCustomTextColorHex)
        }
    }

    private func currentPosition(now: Date) -> TimeInterval? {
        guard isSynced, let track, let position = track.position else {
            return nil
        }

        guard track.state == .playing else {
            return position
        }

        return position + now.timeIntervalSince(track.updatedAt)
    }

    private func activeLineIndex(at position: TimeInterval?) -> Int? {
        guard let position else {
            return nil
        }

        return lines.last(where: { ($0.time ?? .greatestFiniteMagnitude) <= position })?.id
    }
}

private struct LyricsLayoutMetrics {
    let currentFontSize: CGFloat
    let secondaryFontSize: CGFloat
    let rowSpacing: CGFloat
    let internalLineSpacing: CGFloat
    let verticalPadding: CGFloat
    let horizontalInset: CGFloat
    let minimumRowHeight: CGFloat
    let currentScale: CGFloat
    let prefersTightCurrentLine: Bool
}

private struct LyricSeekModifier: ViewModifier {
    let line: LyricLine
    let isSynced: Bool
    @ObservedObject var nowPlayingService: NowPlayingService
    let onInteraction: () -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                guard AppEdition.supportsLyricLineSeeking,
                      isSynced,
                      let time = line.time else {
                    return
                }

                onInteraction()
                nowPlayingService.seek(to: time)
            }
    }
}
