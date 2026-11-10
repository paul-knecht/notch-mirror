import XCTest
@testable import NotchMirror

// Checks the stored setting and the rules for what is visible.
// The tests use their own throwaway preferences, never the real ones.
final class MirrorSettingsTests: XCTestCase {

    let suite = "local.notchmirror.settings-tests"
    var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaultTriggerIsNotch() {
        XCTAssertEqual(MirrorSettings(defaults: defaults).trigger, .notch)
    }

    func testTriggerIsRemembered() {
        MirrorSettings(defaults: defaults).trigger = .menuBarIcon
        XCTAssertEqual(MirrorSettings(defaults: defaults).trigger, .menuBarIcon)
        MirrorSettings(defaults: defaults).trigger = .notch
        XCTAssertEqual(MirrorSettings(defaults: defaults).trigger, .notch)
    }

    func testUnknownStoredValueReadsAsNotch() {
        defaults.set("xyz", forKey: "trigger")
        XCTAssertEqual(MirrorSettings(defaults: defaults).trigger, .notch)
    }

    func testFlagsStartFalseAndAreRemembered() {
        let settings = MirrorSettings(defaults: defaults)
        XCTAssertFalse(settings.didShowWelcome)
        XCTAssertFalse(settings.didSetUpLoginItem)
        settings.didShowWelcome = true
        settings.didSetUpLoginItem = true
        XCTAssertTrue(MirrorSettings(defaults: defaults).didShowWelcome)
        XCTAssertTrue(MirrorSettings(defaults: defaults).didSetUpLoginItem)
    }

    // Icon mode: the icon shows, the notch does not react.
    func testIconMode() {
        for notch in [true, false] {
            XCTAssertTrue(MirrorSettings.showsMenuBarIcon(trigger: .menuBarIcon, notchAvailable: notch))
            XCTAssertFalse(MirrorSettings.showsNotchArea(trigger: .menuBarIcon, notchAvailable: notch))
        }
    }

    // Notch mode: the notch reacts and there is no icon.
    func testNotchModeWithNotch() {
        XCTAssertFalse(MirrorSettings.showsMenuBarIcon(trigger: .notch, notchAvailable: true))
        XCTAssertTrue(MirrorSettings.showsNotchArea(trigger: .notch, notchAvailable: true))
    }

    // Notch mode on a setup without a notch: the icon steps in, so the
    // app stays reachable.
    func testNotchModeWithoutNotchFallsBackToIcon() {
        XCTAssertTrue(MirrorSettings.showsMenuBarIcon(trigger: .notch, notchAvailable: false))
        XCTAssertFalse(MirrorSettings.showsNotchArea(trigger: .notch, notchAvailable: false))
    }
}
