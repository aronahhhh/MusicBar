import AppKit
import SwiftUI

struct MenuBarIslandView: View {
    @ObservedObject var service: NowPlayingService

    var body: some View {
        ZStack {
            if let track = service.track {
                NowPlayingIslandContent(track: track)
                    .id(trackAnimationID(track))
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .bold))
                    Text("MusicBar")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.primary.opacity(0.82))
                .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 24)
        .padding(.vertical, 2)
        .padding(.horizontal, 3)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: service.track?.title)
    }

    private func trackAnimationID(_ track: TrackInfo) -> String {
        "\(track.title)-\(track.artist)-\(track.album)"
    }
}

private struct NowPlayingIslandContent: View {
    let track: TrackInfo

    var body: some View {
        HStack(spacing: 7) {
            ArtworkView(path: track.artworkPath, cornerRadius: 5, refreshID: track.updatedAt)
                .frame(width: 18, height: 18)

            MarqueeTextView(text: "\(track.displayTitle)  ·  \(track.displayArtist)")
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 2)
    }
}

private struct MarqueeTextView: View {
    let text: String

    private let visibleWidth: CGFloat = 173
    private let scrollSpeed: CGFloat = 28
    private let pauseDuration: TimeInterval = 1.4

    var body: some View {
        TimelineView(.animation) { timeline in
            let textWidth = measuredTextWidth(text)
            let overflow = max(0, textWidth - visibleWidth)
            let scrollDuration = overflow > 0 ? TimeInterval(overflow / scrollSpeed) : 0
            let cycleDuration = pauseDuration + scrollDuration + pauseDuration
            let elapsed = cycleDuration > 0 ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration) : 0
            let xOffset = offset(elapsed: elapsed, overflow: overflow, scrollDuration: scrollDuration)

            Text(text)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: xOffset)
                .frame(width: visibleWidth, alignment: textWidth > visibleWidth ? .leading : .center)
                .clipped()
        }
        .frame(width: visibleWidth, height: 16, alignment: .center)
        .id(text)
    }

    private func offset(elapsed: TimeInterval, overflow: CGFloat, scrollDuration: TimeInterval) -> CGFloat {
        guard overflow > 0, scrollDuration > 0 else {
            return 0
        }

        if elapsed < pauseDuration {
            return 0
        }

        if elapsed < pauseDuration + scrollDuration {
            let progress = (elapsed - pauseDuration) / scrollDuration
            return -CGFloat(progress) * overflow
        }

        return -overflow
    }

    private func measuredTextWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

struct IslandView: View {
    @ObservedObject var service: NowPlayingService

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)

            if let track = service.track {
                TrackIslandContent(track: track)
            } else {
                EmptyIslandContent()
            }
        }
        .frame(width: 370, height: 100)
        .padding(8)
    }
}

private struct TrackIslandContent: View {
    let track: TrackInfo

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(path: track.artworkPath, cornerRadius: 18, refreshID: track.updatedAt)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: track.state == .playing ? "waveform" : "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(track.source)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.58))

                Text(track.displayTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(track.displayArtist)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
    }
}

private struct EmptyIslandContent: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text("No Music Playing")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("MusicBar is listening for Apple Music")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
    }
}

struct ArtworkView: View {
    let path: String?
    let cornerRadius: CGFloat
    let refreshID: Date?

    init(path: String?, cornerRadius: CGFloat, refreshID: Date? = nil) {
        self.path = path
        self.cornerRadius = cornerRadius
        self.refreshID = refreshID
    }

    var body: some View {
        Group {
            if let image = imageFromPath(path) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.55, blue: 0.58),
                            Color(red: 0.88, green: 0.22, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .id("\(path ?? "fallback")-\(refreshID?.timeIntervalSinceReferenceDate ?? 0)")
    }

    private func imageFromPath(_ path: String?) -> NSImage? {
        guard let path else {
            return nil
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        return NSImage(data: data)
    }
}
