import AppKit
import SwiftUI

struct ActionPopoverView: View {
    @ObservedObject var license: AppLicense
    let onLyrics: () -> Void
    let onSettings: () -> Void
    let onUpdate: () -> Void
    let onGitHub: () -> Void
    let onPurchase: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppEdition.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(license.statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(license.isEntitled ? Color.secondary : Color.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            ActionButton(title: "Lyrics", systemImage: "quote.bubble", action: onLyrics)
            ActionButton(title: "Settings", systemImage: "gearshape", action: onSettings)
            ActionButton(title: "Update", systemImage: "arrow.down.circle", action: onUpdate)
            ActionButton(title: "GitHub", systemImage: "link", action: onGitHub)
            ActionButton(title: "Purchase", systemImage: "cart", action: onPurchase)

            Divider()
                .padding(.vertical, 2)

            ActionButton(title: "Quit", systemImage: "power", action: onQuit)
        }
        .padding(10)
        .frame(width: 190)
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
    let onPurchase: () -> Void

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

            VStack(alignment: .leading, spacing: 6) {
                Text("License")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack {
                    Text(license.statusText)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button("Purchase", action: onPurchase)
                }
            }

            if AppEdition.supportsAutoLyricsWindow || AppEdition.supportsLaunchAtLogin {
                Divider()
            }

            if AppEdition.supportsAutoLyricsWindow {
                Toggle("Auto Lyrics Window", isOn: $settings.autoShowLyricsWindow)
            }

            if AppEdition.supportsLaunchAtLogin {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }

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

struct PurchaseView: View {
    @ObservedObject var license: AppLicense
    let onPurchase: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(license.isTrialActive ? "MusicBar Trial" : "Trial Expired")
                    .font(.system(size: 20, weight: .semibold))
                Text(license.statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(license.isEntitled ? Color.secondary : Color.red)
            }

            Text("MusicBar includes the full lyrics window, menu bar controls, auto lyrics window, opacity control, always-on-top mode, and launch at login during the 7-day trial.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("After the trial, unlock the full version for $1.99 or RMB 3.99.")
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Button("Not Now", action: onClose)
                Spacer()
                Button("Purchase", action: onPurchase)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
