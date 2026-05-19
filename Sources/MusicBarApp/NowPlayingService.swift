import Combine
import Foundation

struct PlaybackControlState: Equatable {
    var isShuffleEnabled = false
    var isRepeatEnabled = false
}

final class NowPlayingService: ObservableObject {
    @Published private(set) var track: TrackInfo?
    @Published private(set) var isShuffleEnabled = false
    @Published private(set) var isRepeatEnabled = false
    @Published private(set) var volume = 100
    @Published private(set) var outputDevices: [SystemAudioDevice] = []

    private let providers: [MusicProvider]
    private let audioService: SystemAudioService
    private var timer: Timer?
    private var isRefreshing = false
    private var lastRefreshStartedAt = Date.distantPast

    init(providers: [MusicProvider] = [AppleMusicProvider()], audioService: SystemAudioService = SystemAudioService()) {
        self.providers = providers
        self.audioService = audioService
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
        DispatchQueue.global(qos: .utility).async { [providers, audioService] in
            var activeProvider: MusicProvider?
            var nextTrack: TrackInfo?
            for provider in providers {
                if let track = provider.currentTrack() {
                    activeProvider = provider
                    nextTrack = track
                    break
                }
            }
            let controlState = activeProvider?.playbackState() ?? PlaybackControlState()
            let volume = audioService.outputVolume()
            let outputDevices = audioService.outputDevices()

            DispatchQueue.main.async {
                self.isRefreshing = false
                if self.track != nextTrack {
                    self.track = nextTrack
                }
                self.isShuffleEnabled = controlState.isShuffleEnabled
                self.isRepeatEnabled = controlState.isRepeatEnabled
                self.volume = volume
                self.outputDevices = outputDevices
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
        controlActiveProvider { $0.toggleShuffle() }
    }

    func toggleRepeat() {
        controlActiveProvider { $0.toggleRepeat() }
    }

    func setSoundVolume(_ volume: Int) {
        let clampedVolume = min(max(volume, 0), 100)
        self.volume = clampedVolume
        DispatchQueue.global(qos: .utility).async {
            self.audioService.setOutputVolume(clampedVolume)
        }
    }

    func setOutputDevice(_ deviceID: UInt32) {
        outputDevices = outputDevices.map { device in
            SystemAudioDevice(id: device.id, name: device.name, transport: device.transport, isDefault: device.id == deviceID)
        }
        DispatchQueue.global(qos: .utility).async {
            self.audioService.setDefaultOutputDevice(deviceID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.refresh()
            }
        }
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
