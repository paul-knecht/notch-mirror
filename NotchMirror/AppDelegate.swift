import AppKit

// Ties the app together: the click area on the notch, the menu bar icon,
// the mirror panel and the camera.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // True while the automated tests run. Then the app must leave the
    // camera, the login items and other running copies alone.
    let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isRunningTests { return }

        // Only one copy may run; this one replaces any older copy.
        SingleInstance.quitOlderCopies()
    }
}
