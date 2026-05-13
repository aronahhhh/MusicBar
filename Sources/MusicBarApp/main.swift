import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusBarController?
    private var nowPlayingService: NowPlayingService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let service = NowPlayingService()
        let controller = StatusBarController(nowPlayingService: service)
        self.nowPlayingService = service
        self.statusController = controller

        service.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlayingService?.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
