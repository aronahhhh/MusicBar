import SwiftUI

struct LyricsWindowView: View {
    @ObservedObject var service: LyricsService
    @ObservedObject var nowPlayingService: NowPlayingService
    @ObservedObject var settings: AppSettings
    let onOpacityChanged: (Double) -> Void

    var body: some View {
        LyricsDisplayView(
            service: service,
            nowPlayingService: nowPlayingService,
            showsControls: true,
            settings: settings,
            onOpacityChanged: onOpacityChanged
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LyricsDisplayView: View {
    @ObservedObject var service: LyricsService
    @ObservedObject var nowPlayingService: NowPlayingService
    let showsControls: Bool
    let settings: AppSettings?
    var onOpacityChanged: (Double) -> Void = { _ in }
    @State private var showsOpacityPanel = false
    @State private var opacityPanelCloseToken = UUID()
    @State private var showsPlaybackControls = true
    @State private var playbackControlsHideToken = UUID()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.92),
                    Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.94),
                    Color.black.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header

                content
            }
            .padding(showsControls ? 22 : 18)

            if showsControls && showsPlaybackControls {
                VStack {
                    Spacer()
                    PlaybackControlsView(nowPlayingService: nowPlayingService, compact: false)
                        .frame(maxWidth: 360)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.bottom, 22)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.24), value: showsPlaybackControls)
            }
        }
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    revealPlaybackControls()
                }
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let track = nowPlayingService.track {
                ArtworkView(path: track.artworkPath, cornerRadius: 8, refreshID: track.updatedAt)
                    .frame(width: showsControls ? 42 : 32, height: showsControls ? 42 : 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.displayTitle)
                        .font(.system(size: showsControls ? 15 : 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.displayArtist)
                        .font(.system(size: showsControls ? 12 : 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            } else {
                Text("Lyrics")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            if showsControls,
               let settings,
               AppEdition.supportsLyricsWindowPinning || AppEdition.supportsLyricsWindowOpacity {
                lyricsWindowControls(settings: settings, onOpacityChanged: onOpacityChanged)
            }
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

    private func schedulePlaybackControlsHide() {
        guard showsControls else {
            return
        }

        let token = UUID()
        playbackControlsHideToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
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
    @State private var isScrubbing = false
    @State private var scrubPosition: TimeInterval = 0

    init(nowPlayingService: NowPlayingService, compact: Bool = false) {
        self.nowPlayingService = nowPlayingService
        self.compact = compact
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { timeline in
            let track = nowPlayingService.track
            let duration = max(track?.duration ?? 0, 0)
            let livePosition = clampedPosition(for: track, now: timeline.date)
            let sliderValue = isScrubbing ? scrubPosition : livePosition

            VStack(spacing: compact ? 8 : 13) {
                VStack(spacing: compact ? 5 : 9) {
                    ScrubProgressBar(
                        value: sliderValue,
                        duration: duration,
                        isDisabled: duration <= 0,
                        onScrubChanged: { position in
                            scrubPosition = position
                            isScrubbing = true
                        },
                        onScrubEnded: { position in
                            scrubPosition = position
                            isScrubbing = false
                            nowPlayingService.seek(to: position)
                        }
                    )
                    .frame(height: 14)

                    if !compact {
                        HStack {
                            Text(formatTime(sliderValue))
                            Spacer()
                            Text(duration > 0 ? "-\(formatTime(max(duration - sliderValue, 0)))" : "--:--")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    }
                }

                HStack(spacing: compact ? 18 : 28) {
                    Button {
                        nowPlayingService.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: compact ? 15 : 20, weight: .bold))
                            .frame(width: compact ? 24 : 34, height: compact ? 24 : 34)
                            .background(.white.opacity(nowPlayingService.isShuffleEnabled ? 0.3 : 0.13), in: Circle())
                    }

                    Button {
                        nowPlayingService.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: compact ? 20 : 28, weight: .bold))
                    }

                    Button {
                        nowPlayingService.togglePlayPause()
                    } label: {
                        Image(systemName: track?.state == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: compact ? 28 : 38, weight: .bold))
                            .frame(width: compact ? 36 : 50, height: compact ? 34 : 44)
                    }

                    Button {
                        nowPlayingService.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: compact ? 20 : 28, weight: .bold))
                    }

                    Button {
                        nowPlayingService.toggleRepeat()
                    } label: {
                        Image(systemName: "repeat")
                            .font(.system(size: compact ? 15 : 20, weight: .bold))
                            .frame(width: compact ? 24 : 34, height: compact ? 24 : 34)
                            .background(.white.opacity(nowPlayingService.isRepeatEnabled ? 0.3 : 0), in: Circle())
                    }
                }
                .buttonStyle(AppleMusicControlButtonStyle())
                .foregroundStyle(.white.opacity(track == nil ? 0.32 : 0.86))
                .disabled(track == nil)
            }
            .padding(.top, compact ? 0 : 6)
        }
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

private struct ScrubProgressBar: View {
    let value: TimeInterval
    let duration: TimeInterval
    let isDisabled: Bool
    let onScrubChanged: (TimeInterval) -> Void
    let onScrubEnded: (TimeInterval) -> Void

    var body: some View {
        GeometryReader { geometry in
            let progress = duration > 0 ? min(max(value / duration, 0), 1) : 0

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.26))
                    .frame(height: 10)

                Capsule(style: .continuous)
                    .fill(.white.opacity(0.9))
                    .frame(width: geometry.size.width * progress, height: 10)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard !isDisabled else {
                            return
                        }

                        onScrubChanged(position(for: gesture.location.x, width: geometry.size.width))
                    }
                    .onEnded { gesture in
                        guard !isDisabled else {
                            return
                        }

                        onScrubEnded(position(for: gesture.location.x, width: geometry.size.width))
                    }
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            let currentIndex = activeLineIndex(at: currentPosition(now: timeline.date))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .center, spacing: large ? 18 : 12) {
                        ForEach(lines) { line in
                            Text(line.text)
                                .font(.system(size: fontSize(for: line.id, currentIndex: currentIndex), weight: fontWeight(for: line.id, currentIndex: currentIndex), design: .rounded))
                                .foregroundStyle(color(for: line.id, currentIndex: currentIndex))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .scaleEffect(line.id == currentIndex ? 1 : 0.96)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard AppEdition.supportsLyricLineSeeking,
                                          isSynced,
                                          let time = line.time else {
                                        return
                                    }

                                    onInteraction()
                                    nowPlayingService.seek(to: time)
                                }
                                .help(AppEdition.supportsLyricLineSeeking && line.time != nil ? "Jump to this lyric" : "")
                                .animation(.easeInOut(duration: 0.18), value: currentIndex)
                                .id(line.id)
                        }
                    }
                    .padding(.vertical, large ? 120 : 72)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(true)
                .onChange(of: currentIndex) { index in
                    guard let index else {
                        return
                    }

                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }

    private func fontSize(for id: Int, currentIndex: Int?) -> CGFloat {
        guard isSynced, let currentIndex else {
            return large ? 22 : 17
        }

        return id == currentIndex ? (large ? 30 : 22) : (large ? 22 : 16)
    }

    private func fontWeight(for id: Int, currentIndex: Int?) -> Font.Weight {
        guard isSynced, let currentIndex else {
            return .semibold
        }

        return id == currentIndex ? .bold : .semibold
    }

    private func color(for id: Int, currentIndex: Int?) -> Color {
        guard isSynced, let currentIndex else {
            return .white.opacity(0.9)
        }

        let distance = abs(id - currentIndex)
        if distance == 0 {
            return .white
        }
        if distance == 1 {
            return .white.opacity(0.45)
        }
        return .white.opacity(0.22)
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
