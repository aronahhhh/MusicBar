enum AppEdition {
    #if PREVIEW
    static let name = "MusicBar Preview"

    static let supportsAutoLyricsWindow = false
    static let supportsLaunchAtLogin = false
    static let supportsLyricsWindowPinning = false
    static let supportsLyricsWindowOpacity = false
    static let supportsLyricLineSeeking = false
    #else
    static let name = "MusicBar"

    static let supportsAutoLyricsWindow = true
    static let supportsLaunchAtLogin = true
    static let supportsLyricsWindowPinning = true
    static let supportsLyricsWindowOpacity = true
    static let supportsLyricLineSeeking = true
    #endif

    static let githubURLString = "https://github.com/aronahhhh/MusicBar"
}
