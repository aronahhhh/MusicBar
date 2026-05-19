import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ActionPopoverView: View {
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ActionButton(title: "Settings", systemImage: "gearshape", action: onSettings)

            Divider()
                .padding(.vertical, 2)

            ActionButton(title: "Quit", systemImage: "power", action: onQuit)
        }
        .padding(10)
        .frame(width: 156)
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var license: AppLicense
    @ObservedObject var updateService: AppUpdateService
    let onPurchase: () -> Void
    let onGitHub: () -> Void
    let onUpdate: () -> Void

    @State private var selectedTab: SettingsTab = .general

    private var text: SettingsText {
        SettingsText(languageCode: settings.appLanguage.resolvedCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    generalPane
                case .lyrics:
                    lyricsPane
                case .about:
                    aboutPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            updateService.setAutomaticallyChecksForUpdates(settings.autoCheckForUpdates)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(AppEdition.name)
                .font(.system(size: 20, weight: .semibold))

            HStack(spacing: 34) {
                SettingsTabButton(tab: .general, selectedTab: $selectedTab, text: text)
                SettingsTabButton(tab: .lyrics, selectedTab: $selectedTab, text: text)
                SettingsTabButton(tab: .about, selectedTab: $selectedTab, text: text)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var generalPane: some View {
        FormPane {
            PreferenceRow(title: text.language, subtitle: text.languageHint) {
                Picker("", selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }

            PreferenceToggleRow(
                title: text.showInMenuBar,
                subtitle: text.showInMenuBarHint,
                isOn: $settings.showNowPlayingInMenuBar
            )

            PreferenceToggleRow(
                title: text.hoverControls,
                subtitle: text.hoverControlsHint,
                isOn: $settings.showHoverPlaybackControls
            )

            PreferenceToggleRow(
                title: text.launchAtLogin,
                subtitle: text.launchAtLoginHint,
                isOn: $settings.launchAtLogin
            )

            PreferenceToggleRow(
                title: text.autoUpdate,
                subtitle: updateService.isSparkleAvailable ? text.autoUpdateHint : text.updateFallbackHint,
                isOn: Binding(
                    get: { settings.autoCheckForUpdates },
                    set: { value in
                        settings.autoCheckForUpdates = value
                        updateService.setAutomaticallyChecksForUpdates(value)
                    }
                )
            )

            PreferenceRow(title: text.license, subtitle: license.statusText) {
                Button(text.purchase, action: onPurchase)
            }
        }
    }

    private var lyricsPane: some View {
        FormPane {
            VStack(spacing: 0) {
                Group {
                    PreferenceToggleRow(
                        title: text.autoLyrics,
                        subtitle: text.autoLyricsHint,
                        isOn: $settings.autoShowLyricsWindow
                    )

                    PreferenceRow(title: text.theme, subtitle: text.themeHint) {
                        Picker("", selection: $settings.lyricsTheme) {
                            ForEach(LyricsTheme.allCases) { theme in
                                Text(text.themeName(theme)).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    PreferenceSliderRow(
                        title: text.fontSize,
                        value: $settings.lyricsFontScale,
                        range: 0.82...1.28,
                        valueText: "\(Int(settings.lyricsFontScale * 100))%"
                    )

                    PreferenceSliderRow(
                        title: text.lineSpacing,
                        value: $settings.lyricsLineSpacing,
                        range: 0.75...1.35,
                        valueText: "\(Int(settings.lyricsLineSpacing * 100))%"
                    )

                    PreferenceRow(title: text.textColor, subtitle: text.textColorHint) {
                        Picker("", selection: $settings.lyricsTextColorMode) {
                            ForEach(LyricsTextColorMode.allCases) { mode in
                                Text(text.textColorName(mode)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 125)
                    }

                    if settings.lyricsTextColorMode == .custom {
                        PreferenceRow(title: text.customTextColor, subtitle: settings.lyricsCustomTextColorHex) {
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: settings.lyricsCustomTextColorHex) },
                                set: { settings.lyricsCustomTextColorHex = $0.hexString }
                            ))
                            .labelsHidden()
                            .frame(width: 52)
                        }
                    }

                    PreferenceRow(title: text.background, subtitle: text.backgroundHint) {
                        Picker("", selection: $settings.lyricsBackgroundMode) {
                            ForEach(LyricsBackgroundMode.allCases) { mode in
                                Text(text.backgroundName(mode)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 125)
                    }
                }

                Group {
                    if settings.lyricsBackgroundMode == .custom {
                        PreferenceRow(title: text.customBackground, subtitle: settings.lyricsCustomBackgroundColorHex) {
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: settings.lyricsCustomBackgroundColorHex) },
                                set: { settings.lyricsCustomBackgroundColorHex = $0.hexString }
                            ))
                            .labelsHidden()
                            .frame(width: 52)
                        }
                    }

                    if settings.lyricsBackgroundMode == .image {
                        PreferenceRow(title: text.backgroundImage, subtitle: imageSubtitle) {
                            Button(text.choose, action: chooseBackgroundImage)
                        }
                    }

                    PreferenceSliderRow(
                        title: text.backgroundDim,
                        value: $settings.lyricsBackgroundDim,
                        range: 0.0...0.86,
                        valueText: "\(Int(settings.lyricsBackgroundDim * 100))%"
                    )

                    PreferenceSliderRow(
                        title: text.backgroundBlur,
                        value: $settings.lyricsBackgroundBlur,
                        range: 0.0...18.0,
                        valueText: "\(Int(settings.lyricsBackgroundBlur))"
                    )

                    PreferenceSliderRow(
                        title: text.windowOpacity,
                        value: $settings.lyricsWindowOpacity,
                        range: 0.18...1.0,
                        valueText: "\(Int(settings.lyricsWindowOpacity * 100))%"
                    )

                    PreferenceToggleRow(
                        title: text.alwaysOnTop,
                        subtitle: text.alwaysOnTopHint,
                        isOn: $settings.lyricsWindowAlwaysOnTop
                    )
                }
            }
        }
    }

    private var aboutPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.18), radius: 7, x: 0, y: 3)

                VStack(spacing: 4) {
                    Text(AppEdition.name)
                        .font(.system(size: 22, weight: .semibold))
                    Text(appVersionText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(license.statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(license.isEntitled ? Color.secondary : Color.red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
            .padding(.bottom, 30)

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                AboutButton(title: text.github, systemImage: "arrow.triangle.branch", action: onGitHub)
                AboutButton(title: text.update, systemImage: "arrow.down.circle", action: onUpdate)
                AboutButton(title: text.website, systemImage: "safari", action: onGitHub)
                AboutButton(title: text.purchase, systemImage: "cart", action: onPurchase)
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 28)

            Divider()

            Text(text.regionPricingText(license))
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    private var imageSubtitle: String {
        settings.lyricsBackgroundImagePath.isEmpty ? text.noImageSelected : URL(fileURLWithPath: settings.lyricsBackgroundImagePath).lastPathComponent
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.lyricsBackgroundImagePath = url.path
        }
    }
}

enum SettingsTab: String, CaseIterable {
    case general
    case lyrics
    case about

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .lyrics:
            return "quote.bubble"
        case .about:
            return "info.circle"
        }
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsTab
    @Binding var selectedTab: SettingsTab
    let text: SettingsText

    var body: some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 28, weight: .medium))
                Text(text.tabTitle(tab))
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
            .frame(width: 88, height: 72)
            .background(selectedTab == tab ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct FormPane<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 34)
        .padding(.top, 14)
    }
}

private struct PreferenceRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 16)
            control
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        PreferenceRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct PreferenceSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String

    var body: some View {
        PreferenceRow(title: title, subtitle: valueText) {
            Slider(value: $value, in: range)
                .frame(width: 178)
        }
    }
}

private struct AboutButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.accentColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: 38)
    }
}

struct SettingsText {
    let languageCode: String

    var language: String { value("Language", "语言", "語言") }
    var languageHint: String { value("Use the system language by default.", "默认跟随系统语言。", "預設跟隨系統語言。") }
    var showInMenuBar: String { value("Show in Menu Bar", "在菜单栏中显示", "在選單列中顯示") }
    var showInMenuBarHint: String { value("Show cover art, title, and artist in the menu bar.", "在菜单栏显示封面、歌名和歌手。", "在選單列顯示封面、歌名與歌手。") }
    var hoverControls: String { value("Hover Playback Controls", "悬停显示播放控制", "懸停顯示播放控制") }
    var hoverControlsHint: String { value("Show compact playback controls when hovering over the menu bar item.", "鼠标悬停在菜单栏项目上时显示小型播放控制。", "滑鼠懸停在選單列項目上時顯示小型播放控制。") }
    var launchAtLogin: String { value("Launch at Login", "开机启动", "開機啟動") }
    var launchAtLoginHint: String { value("Open MusicBar automatically when you log in.", "登录 macOS 后自动打开 MusicBar。", "登入 macOS 後自動開啟 MusicBar。") }
    var license: String { value("License", "授权", "授權") }
    var purchase: String { value("Purchase", "购买", "購買") }
    var autoLyrics: String { value("Auto Show and Hide Lyrics", "自动显示/隐藏歌词", "自動顯示/隱藏歌詞") }
    var autoLyricsHint: String { value("Show the lyrics window while music plays and hide it when paused.", "播放时自动显示歌词窗口，暂停时自动隐藏。", "播放時自動顯示歌詞視窗，暫停時自動隱藏。") }
    var theme: String { value("Lyrics Theme", "歌词主题", "歌詞主題") }
    var themeHint: String { value("Customize the lyrics window atmosphere.", "自定义歌词窗口的视觉氛围。", "自訂歌詞視窗的視覺氛圍。") }
    var fontSize: String { value("Lyric Size", "歌词字号", "歌詞字號") }
    var lineSpacing: String { value("Line Spacing", "歌词行距", "歌詞行距") }
    var windowOpacity: String { value("Window Opacity", "窗口透明度", "視窗透明度") }
    var alwaysOnTop: String { value("Always on Top", "置顶显示", "置頂顯示") }
    var alwaysOnTopHint: String { value("Keep the lyrics window above other windows.", "让歌词窗口保持在其他窗口上方。", "讓歌詞視窗保持在其他視窗上方。") }
    var autoUpdate: String { value("Automatic Updates", "自动检查更新", "自動檢查更新") }
    var autoUpdateHint: String { value("Check for new MusicBar releases automatically.", "自动检查新的 MusicBar 版本。", "自動檢查新的 MusicBar 版本。") }
    var updateFallbackHint: String { value("Sparkle is not embedded; manual release page will be opened.", "当前构建未嵌入 Sparkle，会打开手动下载页。", "目前建置未嵌入 Sparkle，會開啟手動下載頁。") }
    var textColor: String { value("Lyric Color", "歌词颜色", "歌詞顏色") }
    var textColorHint: String { value("Choose white, black, or a custom color.", "选择白色、黑色或自定义颜色。", "選擇白色、黑色或自訂顏色。") }
    var customTextColor: String { value("Custom Lyric Color", "自定义歌词颜色", "自訂歌詞顏色") }
    var background: String { value("Background", "背景", "背景") }
    var backgroundHint: String { value("Use a preset, custom color, or image.", "使用预设色、自定义颜色或图片。", "使用預設色、自訂顏色或圖片。") }
    var customBackground: String { value("Custom Background", "自定义背景色", "自訂背景色") }
    var backgroundImage: String { value("Background Image", "背景图片", "背景圖片") }
    var noImageSelected: String { value("No image selected.", "未选择图片。", "未選擇圖片。") }
    var choose: String { value("Choose", "选择", "選擇") }
    var backgroundDim: String { value("Background Dim", "背景暗化", "背景暗化") }
    var backgroundBlur: String { value("Background Blur", "背景模糊", "背景模糊") }
    var github: String { value("View on GitHub", "上 GitHub 查看", "到 GitHub 查看") }
    var update: String { value("Check for Updates", "检查更新", "檢查更新") }
    var website: String { value("Visit Website", "访问网站", "造訪網站") }
    var trialTitle: String { value("MusicBar Trial", "MusicBar 试用", "MusicBar 試用") }
    var trialExpired: String { value("Trial Expired", "试用已结束", "試用已結束") }
    var trialDescription: String {
        value(
            "MusicBar includes the full lyrics window, menu bar controls, auto lyrics window, opacity control, always-on-top mode, and launch at login during the 7-day trial.",
            "7 天试用期间，MusicBar 会开放完整歌词窗口、菜单栏控制、自动歌词窗口、透明度控制、置顶显示和开机启动。",
            "7 天試用期間，MusicBar 會開放完整歌詞視窗、選單列控制、自動歌詞視窗、透明度控制、置頂顯示和開機啟動。"
        )
    }

    func unlockText(_ price: String) -> String {
        value(
            "After the trial, unlock the full version for \(price).",
            "试用结束后，可以用 \(price) 解锁完整版本。",
            "試用結束後，可以用 \(price) 解鎖完整版本。"
        )
    }

    func regionPricingText(_ license: AppLicense) -> String {
        value(
            "The full version price in your country or region is \(license.localizedPrice).",
            "在您的国家或者地区完整版本价格为 \(license.localizedPrice)。",
            "在您的國家或者地區完整版本價格為 \(license.localizedPrice)。"
        )
    }

    func tabTitle(_ tab: SettingsTab) -> String {
        switch tab {
        case .general:
            return value("General", "通用", "通用")
        case .lyrics:
            return value("Lyrics", "歌词", "歌詞")
        case .about:
            return value("About", "关于", "關於")
        }
    }

    func themeName(_ theme: LyricsTheme) -> String {
        switch theme {
        case .midnight:
            return value("Midnight", "深夜", "深夜")
        case .glass:
            return value("Glass", "玻璃", "玻璃")
        case .warm:
            return value("Warm", "暖色", "暖色")
        }
    }

    func textColorName(_ mode: LyricsTextColorMode) -> String {
        switch mode {
        case .white:
            return value("White", "白色", "白色")
        case .black:
            return value("Black", "黑色", "黑色")
        case .custom:
            return value("Custom", "自定义", "自訂")
        }
    }

    func backgroundName(_ mode: LyricsBackgroundMode) -> String {
        switch mode {
        case .midnight:
            return value("Midnight", "深夜", "深夜")
        case .graphite:
            return value("Graphite", "石墨", "石墨")
        case .ivory:
            return value("Ivory", "象牙白", "象牙白")
        case .custom:
            return value("Custom", "自定义", "自訂")
        case .image:
            return value("Image", "图片", "圖片")
        }
    }

    private func value(_ english: String, _ simplified: String, _ traditional: String) -> String {
        if languageCode == "zh-Hans" {
            return simplified
        }
        if languageCode == "zh-Hant" {
            return traditional
        }
        return english
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: cleaned)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }

    var hexString: String {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else {
            return "#FFFFFF"
        }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

struct PurchaseView: View {
    @ObservedObject var license: AppLicense
    let text: SettingsText
    let onPurchase: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(license.isTrialActive ? text.trialTitle : text.trialExpired)
                    .font(.system(size: 20, weight: .semibold))
                Text(license.statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(license.isEntitled ? Color.secondary : Color.red)
            }

            Text(text.trialDescription)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(text.unlockText(license.localizedPrice))
                .font(.system(size: 13, weight: .semibold))

            Text(text.regionPricingText(license))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(value("Not Now", "暂不", "暫不"), action: onClose)
                Spacer()
                Button(text.purchase, action: onPurchase)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func value(_ english: String, _ simplified: String, _ traditional: String) -> String {
        if text.languageCode == "zh-Hans" {
            return simplified
        }
        if text.languageCode == "zh-Hant" {
            return traditional
        }
        return english
    }
}
