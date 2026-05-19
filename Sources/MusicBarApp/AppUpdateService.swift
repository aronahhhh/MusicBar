import AppKit
import Combine

#if canImport(Sparkle)
import Sparkle
#endif

final class AppUpdateService: ObservableObject {
    @Published private(set) var isSparkleAvailable = false

    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        isSparkleAvailable = true
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    #else
    init() {}

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {}

    func checkForUpdates() {
        NSWorkspace.shared.open(URL(string: AppEdition.githubURLString + "/releases")!)
    }
    #endif
}
