import Combine
import Foundation

final class NowPlayingService: ObservableObject {
    @Published private(set) var track: TrackInfo?
    @Published private(set) var isShuffleEnabled = false
    @Published private(set) var isRepeatEnabled = false

    private let providers: [MusicProvider]
    private var timer: Timer?
    private var isRefreshing = false
    private var lastRefreshStartedAt = Date.distantPast

    init(providers: [MusicProvider] = [AppleMusicProvider()]) {
        self.providers = providers
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 0.15
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        if isRefreshing {
            if Date().timeIntervalSince(lastRefreshStartedAt) > 4 {
                isRefreshing = false
            } else {
                return
            }
        }

        isRefreshing = true
        lastRefreshStartedAt = Date()
        DispatchQueue.global(qos: .utility).async { [providers] in
            let nextTrack = providers.compactMap { $0.currentTrack() }.first

            DispatchQueue.main.async {
                self.isRefreshing = false
                if self.track != nextTrack {
                    self.track = nextTrack
                }
            }
        }
    }

    func togglePlayPause() {
        controlActiveProvider { $0.togglePlayPause() }
    }

    func nextTrack() {
        controlActiveProvider { $0.nextTrack() }
    }

    func previousTrack() {
        controlActiveProvider { $0.previousTrack() }
    }

    func seek(to position: TimeInterval) {
        controlActiveProvider { $0.seek(to: position) }
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
        controlActiveProvider { $0.toggleShuffle() }
    }

    func toggleRepeat() {
        isRepeatEnabled.toggle()
        controlActiveProvider { $0.toggleRepeat() }
    }

    private func controlActiveProvider(_ action: @escaping (MusicProvider) -> Void) {
        guard let source = track?.source,
              let provider = providers.first(where: { $0.sourceName == source }) else {
            return
        }

        DispatchQueue.global(qos: .utility).async {
            action(provider)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.refresh()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                self.refresh()
            }
        }
    }
}
