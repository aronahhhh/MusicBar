import SwiftUI

struct HoverPlaybackControlsView: View {
    @ObservedObject var nowPlayingService: NowPlayingService
    let onMouseEntered: () -> Void
    let onMouseExited: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.92),
                    Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            PlaybackControlsView(nowPlayingService: nowPlayingService, compact: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .frame(width: 300, height: 92)
        .onHover { hovering in
            if hovering {
                onMouseEntered()
            } else {
                onMouseExited()
            }
        }
    }
}
