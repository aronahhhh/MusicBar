import AppKit
import SwiftUI

struct ActionPopoverView: View {
    let onLyrics: () -> Void
    let onSettings: () -> Void
    let onUpdate: () -> Void
    let onGitHub: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ActionButton(title: "Lyrics", systemImage: "quote.bubble", action: onLyrics)
            ActionButton(title: "Settings", systemImage: "gearshape", action: onSettings)
            ActionButton(title: "Update", systemImage: "arrow.down.circle", action: onUpdate)
            ActionButton(title: "GitHub", systemImage: "link", action: onGitHub)

            Divider()
                .padding(.vertical, 2)

            ActionButton(title: "Quit", systemImage: "power", action: onQuit)
        }
        .padding(10)
        .frame(width: 176)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                Text(AppEdition.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("GitHub Homepage")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(AppEdition.githubURLString, text: $settings.githubURLString)
                    .textFieldStyle(.roundedBorder)
            }

            #if !PREVIEW
            if AppEdition.supportsAutoLyricsWindow || AppEdition.supportsLaunchAtLogin {
                Divider()
            }

            if AppEdition.supportsAutoLyricsWindow {
                Toggle("Auto Lyrics Window", isOn: $settings.autoShowLyricsWindow)
            }

            if AppEdition.supportsLaunchAtLogin {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }
            #endif

            HStack {
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 360)
    }
}
