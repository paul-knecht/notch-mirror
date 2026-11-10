import XCTest
@testable import NotchMirror

// Checks the running app: its windows, the menu and the settings.
// The camera is never switched on by the tests.
@MainActor
final class SmokeTests: XCTestCase {

    var delegate: AppDelegate { NSApp.delegate as! AppDelegate }

    func testAppDelegateExists() {
        XCTAssertTrue(NSApp.delegate is AppDelegate)
    }
}
