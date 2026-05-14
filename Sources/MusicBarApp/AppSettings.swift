import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese
    case traditionalChinese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        case .english:
            return "English"
        }
    }

    var resolvedCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            if preferred.hasPrefix("zh-hant") || preferred.contains("tw") || preferred.contains("hk") {
                return "zh-Hant"
            }
            if preferred.hasPrefix("zh") {
                return "zh-Hans"
            }
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        case .english:
            return "en"
        }
    }
}

enum LyricsTheme: String, CaseIterable, Identifiable {
    case midnight
    case glass
    case warm

    var id: String { rawValue }
}

final class AppSettings: ObservableObject {
    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: appLanguageKey)
        }
    }
    @Published var showNowPlayingInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showNowPlayingInMenuBar, forKey: showNowPlayingInMenuBarKey)
        }
    }
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
    @Published var lyricsTheme: LyricsTheme {
        didSet {
            UserDefaults.standard.set(lyricsTheme.rawValue, forKey: lyricsThemeKey)
        }
    }
    @Published var lyricsFontScale: Double {
        didSet {
            UserDefaults.standard.set(lyricsFontScale, forKey: lyricsFontScaleKey)
        }
    }
    @Published var lyricsLineSpacing: Double {
        didSet {
            UserDefaults.standard.set(lyricsLineSpacing, forKey: lyricsLineSpacingKey)
        }
    }

    private let appLanguageKey = "appLanguage"
    private let showNowPlayingInMenuBarKey = "showNowPlayingInMenuBar"
    private let githubURLKey = "githubURLString"
    private let lyricsWindowOpacityKey = "lyricsWindowOpacity"
    private let lyricsWindowAlwaysOnTopKey = "lyricsWindowAlwaysOnTop"
    private let autoShowLyricsWindowKey = "autoShowLyricsWindow"
    private let launchAtLoginKey = "launchAtLogin"
    private let lyricsThemeKey = "lyricsTheme"
    private let lyricsFontScaleKey = "lyricsFontScale"
    private let lyricsLineSpacingKey = "lyricsLineSpacing"

    init() {
        let savedLanguage = UserDefaults.standard.string(forKey: appLanguageKey)
        appLanguage = savedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .system
        if UserDefaults.standard.object(forKey: showNowPlayingInMenuBarKey) == nil {
            showNowPlayingInMenuBar = true
        } else {
            showNowPlayingInMenuBar = UserDefaults.standard.bool(forKey: showNowPlayingInMenuBarKey)
        }
        githubURLString = UserDefaults.standard.string(forKey: githubURLKey) ?? AppEdition.githubURLString
        let savedOpacity = UserDefaults.standard.double(forKey: lyricsWindowOpacityKey)
        lyricsWindowOpacity = savedOpacity == 0 ? 0.88 : max(0.18, savedOpacity)
        lyricsWindowAlwaysOnTop = UserDefaults.standard.bool(forKey: lyricsWindowAlwaysOnTopKey)
        autoShowLyricsWindow = UserDefaults.standard.bool(forKey: autoShowLyricsWindowKey)
        launchAtLogin = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        let savedTheme = UserDefaults.standard.string(forKey: lyricsThemeKey)
        lyricsTheme = savedTheme.flatMap(LyricsTheme.init(rawValue:)) ?? .midnight
        let savedFontScale = UserDefaults.standard.double(forKey: lyricsFontScaleKey)
        lyricsFontScale = savedFontScale == 0 ? 1.0 : min(max(savedFontScale, 0.82), 1.28)
        let savedLineSpacing = UserDefaults.standard.double(forKey: lyricsLineSpacingKey)
        lyricsLineSpacing = savedLineSpacing == 0 ? 1.0 : min(max(savedLineSpacing, 0.75), 1.35)
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
