import Foundation

final class AppSettings: ObservableObject {
    @Published var githubURLString: String {
        didSet {
            UserDefaults.standard.set(githubURLString, forKey: githubURLKey)
        }
    }
    @Published var lyricsWindowOpacity: Double {
        didSet {
            UserDefaults.standard.set(lyricsWindowOpacity, forKey: lyricsWindowOpacityKey)
        }
    }
    @Published var lyricsWindowAlwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(lyricsWindowAlwaysOnTop, forKey: lyricsWindowAlwaysOnTopKey)
        }
    }
    @Published var autoShowLyricsWindow: Bool {
        didSet {
            UserDefaults.standard.set(autoShowLyricsWindow, forKey: autoShowLyricsWindowKey)
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: launchAtLoginKey)
            configureLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    private let githubURLKey = "githubURLString"
    private let lyricsWindowOpacityKey = "lyricsWindowOpacity"
    private let lyricsWindowAlwaysOnTopKey = "lyricsWindowAlwaysOnTop"
    private let autoShowLyricsWindowKey = "autoShowLyricsWindow"
    private let launchAtLoginKey = "launchAtLogin"

    init() {
        githubURLString = UserDefaults.standard.string(forKey: githubURLKey) ?? AppEdition.githubURLString
        let savedOpacity = UserDefaults.standard.double(forKey: lyricsWindowOpacityKey)
        lyricsWindowOpacity = savedOpacity == 0 ? 0.88 : max(0.18, savedOpacity)
        lyricsWindowAlwaysOnTop = UserDefaults.standard.bool(forKey: lyricsWindowAlwaysOnTopKey)
        autoShowLyricsWindow = UserDefaults.standard.bool(forKey: autoShowLyricsWindowKey)
        launchAtLogin = UserDefaults.standard.bool(forKey: launchAtLoginKey)
    }

    var githubURL: URL {
        URL(string: githubURLString) ?? URL(string: "https://github.com/")!
    }

    var releasesURL: URL {
        let trimmed = githubURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmed.contains("github.com/"),
              trimmed.components(separatedBy: "/").count >= 4,
              let url = URL(string: trimmed + "/releases") else {
            return githubURL
        }

        return url
    }

    private func configureLaunchAtLogin(enabled: Bool) {
        let fileManager = FileManager.default
        guard let launchAgentsURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("LaunchAgents") else {
            return
        }

        let plistURL = launchAgentsURL.appendingPathComponent("local.musicbar.app.plist")

        if enabled {
            guard Bundle.main.bundlePath.hasSuffix(".app") else {
                return
            }

            try? fileManager.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)
            let appPath = Bundle.main.bundlePath
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>local.musicbar.app</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/usr/bin/open</string>
                    <string>\(appPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """
            try? plist.write(to: plistURL, atomically: true, encoding: .utf8)
        } else {
            try? fileManager.removeItem(at: plistURL)
        }
    }
}
