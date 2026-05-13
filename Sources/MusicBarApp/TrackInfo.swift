import Foundation

enum PlaybackState: String, Equatable {
    case playing
    case paused
    case stopped
}

struct TrackInfo: Equatable {
    let source: String
    let title: String
    let artist: String
    let album: String
    let state: PlaybackState
    let artworkPath: String?
    let position: TimeInterval?
    let duration: TimeInterval?
    let updatedAt: Date

    var displayTitle: String {
        title.isEmpty ? "No Track" : title
    }

    var displayArtist: String {
        artist.isEmpty ? source : artist
    }
}
