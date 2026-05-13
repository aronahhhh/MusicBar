import Foundation

protocol MusicProvider {
    var sourceName: String { get }
    func currentTrack() -> TrackInfo?
    func togglePlayPause()
    func nextTrack()
    func previousTrack()
    func seek(to position: TimeInterval)
    func toggleShuffle()
    func toggleRepeat()
}

extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private func parseTrackResponse(_ response: String, source: String, artworkPath: String) -> TrackInfo? {
    let parts = response.components(separatedBy: "\t")
    guard parts.count >= 4 else {
        return nil
    }

    let state = PlaybackState(rawValue: parts[0].lowercased()) ?? .stopped
    guard state != .stopped else {
        return nil
    }

    let existingArtworkPath = FileManager.default.fileExists(atPath: artworkPath) ? artworkPath : nil
    return TrackInfo(
        source: source,
        title: parts[1],
        artist: parts[2],
        album: parts[3],
        state: state,
        artworkPath: existingArtworkPath,
        position: parts.count >= 5 ? TimeInterval(parts[4]) : nil,
        duration: parts.count >= 6 ? TimeInterval(parts[5]) : nil,
        updatedAt: Date()
    )
}

struct AppleMusicProvider: MusicProvider {
    let sourceName = "Apple Music"
    private let runner = AppleScriptRunner()
    private let artworkPath = NSTemporaryDirectory() + "musicbar-apple-music-artwork"

    func currentTrack() -> TrackInfo? {
        let escapedPath = artworkPath.appleScriptEscaped
        let script = """
        if application "Music" is running then
            tell application "Music"
                if player state is playing or player state is paused then
                    set trackName to name of current track as text
                    set trackArtist to artist of current track as text
                    set trackAlbum to album of current track as text
                    set playState to player state as text
                    set trackPosition to player position as text
                    set trackDuration to duration of current track as text
                    try
                        set artFile to POSIX file "\(escapedPath)"
                        set artData to raw data of artwork 1 of current track
                        set fileRef to open for access artFile with write permission
                        set eof of fileRef to 0
                        write artData to fileRef
                        close access fileRef
                    on error
                        try
                            close access POSIX file "\(escapedPath)"
                        end try
                    end try
                    return playState & tab & trackName & tab & trackArtist & tab & trackAlbum & tab & trackPosition & tab & trackDuration
                end if
            end tell
        end if
        return ""
        """

        guard let response = runner.run(script), !response.isEmpty else {
            return nil
        }

        return parseTrackResponse(response, source: sourceName, artworkPath: artworkPath)
    }

    func togglePlayPause() {
        _ = runner.run("""
        if application "Music" is running then
            tell application "Music" to playpause
        end if
        """)
    }

    func nextTrack() {
        _ = runner.run("""
        if application "Music" is running then
            tell application "Music" to next track
        end if
        """)
    }

    func previousTrack() {
        _ = runner.run("""
        if application "Music" is running then
            tell application "Music" to previous track
        end if
        """)
    }

    func seek(to position: TimeInterval) {
        _ = runner.run("""
        if application "Music" is running then
            tell application "Music" to set player position to \(max(0, position))
        end if
        """)
    }

    func toggleShuffle() {
        _ = runner.run("""
        if application "Music" is running then
            tell application "Music"
                set shuffle enabled to (not (shuffle enabled as boolean))
            end tell
        end if
        """)
    }

    func toggleRepeat() {
        _ = runner.run("""
        if application "Music" is running then
            tell application "Music"
                if song repeat is off then
                    set song repeat to all
                else
                    set song repeat to off
                end if
            end tell
        end if
        """)
    }
}
