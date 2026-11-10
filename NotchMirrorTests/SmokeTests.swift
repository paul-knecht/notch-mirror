import XCTest
@testable import NotchMirror

// Checks the running app: its windows, the menu and the settings.
// The camera is never switched on by the tests, and the settings they
// change live in throwaway preferences, not the real ones.
@MainActor
final class SmokeTests: XCTestCase {

    var delegate: AppDelegate { NSApp.delegate as! AppDelegate }

    // A 15-inch MacBook Air: 1710 x 1107 points with a 185 x 33.5 notch.
    let mac = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                         safeTop: 33.5,
                         topLeft: CGRect(x: 0, y: 1073.5, width: 762.5, height: 33.5),
                         topRight: CGRect(x: 947.5, y: 1073.5, width: 762.5, height: 33.5))

    override func tearDown() async throws {
        delegate.closeMirror()
        delegate.setTrigger(.notch)
        delegate.settingsWindow?.close()
    }

    func testAppDelegateExists() {
        XCTAssertTrue(NSApp.delegate is AppDelegate)
    }

    // MARK: - Menu

    func testMenuTitlesAndCheckmark() {
        delegate.setTrigger(.menuBarIcon)
        let items = delegate.buildMenu().items
        XCTAssertEqual(items.map(\.title),
                       ["Open from", "Notch", "Menu Bar Icon", "", "Start at Login", "", "Quit NotchMirror"])
        XCTAssertFalse(items[0].isEnabled)
        XCTAssertEqual(items[1].state, .off)
        XCTAssertEqual(items[2].state, .on)
        XCTAssertTrue(items[3].isSeparatorItem)
        XCTAssertTrue(items[5].isSeparatorItem)

        delegate.setTrigger(.notch)
        let again = delegate.buildMenu().items
        XCTAssertEqual(again[1].state, .on)
        XCTAssertEqual(again[2].state, .off)
    }

    // MARK: - What is visible

    func testIconModeShowsIconAndHidesNotchArea() {
        delegate.setTrigger(.menuBarIcon)
        delegate.applyVisibility(notchScreen: mac)
        XCTAssertTrue(delegate.statusItem.isVisible)
        XCTAssertFalse(delegate.clickArea.isVisible)
    }

    func testNotchModeWithNotchShowsAreaAndHidesIcon() {
        delegate.setTrigger(.notch)
        delegate.applyVisibility(notchScreen: mac)
        XCTAssertFalse(delegate.statusItem.isVisible)
        XCTAssertTrue(delegate.clickArea.isVisible)
        XCTAssertEqual(delegate.clickArea.frame, CGRect(x: 767, y: 1077, width: 176, height: 30))
    }

    // Without a notch the icon steps in, so the app stays reachable.
    func testNotchModeWithoutNotchShowsIcon() {
        delegate.setTrigger(.notch)
        delegate.applyVisibility(notchScreen: nil)
        XCTAssertTrue(delegate.statusItem.isVisible)
        XCTAssertFalse(delegate.clickArea.isVisible)
    }

    // MARK: - Opening and closing

    func testToggleOpensAndClosesPanel() {
        XCTAssertFalse(delegate.panel.isVisible)
        delegate.toggleMirror()
        XCTAssertTrue(delegate.panel.isVisible)
        XCTAssertTrue(delegate.logic.isOpen)
        delegate.toggleMirror()
        XCTAssertFalse(delegate.panel.isVisible)
        XCTAssertFalse(delegate.logic.isOpen)
    }

    // The click area must lie above the open panel. Otherwise the panel
    // covers it, and a second click on the notch could not close the mirror.
    func testClickAreaLiesAboveThePanel() {
        XCTAssertGreaterThan(delegate.clickArea.level.rawValue, delegate.panel.level.rawValue)
    }

    // The click area must not be visible, so it is almost fully
    // see-through. "Almost" matters: macOS hands clicks to a window that
    // is 1% visible, but lets them fall through one that is 0% visible.
    func testClickAreaIsAlmostButNotFullySeeThrough() {
        XCTAssertFalse(delegate.clickArea.isOpaque)
        let alpha = delegate.clickArea.backgroundColor.alphaComponent
        XCTAssertLessThan(alpha, 0.05)
        XCTAssertGreaterThan(alpha, 0)
    }

    // MARK: - The setting is remembered

    func testSetTriggerPersists() {
        delegate.setTrigger(.menuBarIcon)
        XCTAssertEqual(MirrorSettings(defaults: delegate.settings.defaults).trigger, .menuBarIcon)
    }

    // The tests must never write into the app's real preferences.
    func testTestsUseThrowawayPreferences() {
        XCTAssertFalse(delegate.settings.defaults === UserDefaults.standard)
    }

    // MARK: - Settings window

    func testSettingsWindowOpens() {
        delegate.showSettings(welcome: false)
        let window = delegate.settingsWindow
        XCTAssertEqual(window?.title, "NotchMirror")
        XCTAssertEqual(window?.isVisible, true)
    }

    // The first-launch hint names the trigger that is really there.
    func testWelcomeText() {
        XCTAssertEqual(SettingsView.welcomeText(notchAvailable: true),
                       "Click the notch to open the mirror. Right-click it for these settings.")
        XCTAssertEqual(SettingsView.welcomeText(notchAvailable: false),
                       "Click the icon in the menu bar to open the mirror. Right-click it for these settings.")
    }

    func testCameraAccessLine() {
        XCTAssertEqual(SettingsView.accessText(.granted), "Camera access: granted")
        XCTAssertEqual(SettingsView.accessText(.notAsked),
                       "Camera access: not asked yet. macOS asks the first time you open the mirror.")
        XCTAssertEqual(SettingsView.accessText(.denied), "Camera access: denied")
    }

    // MARK: - Texts

    func testMessages() {
        XCTAssertEqual(MirrorPanel.message(for: .picture), "")
        XCTAssertEqual(MirrorPanel.message(for: .waitingForAccess), "Waiting for camera access…")
        XCTAssertEqual(MirrorPanel.message(for: .noAccess), "NotchMirror has no access to the camera.")
        XCTAssertEqual(MirrorPanel.message(for: .noCamera), "No built-in camera found.")
    }
}
