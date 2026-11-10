import XCTest
@testable import NotchMirror

// Checks where the notch, the panel, the picture and the click area go.
// All numbers are in points; y grows upwards, as everywhere in AppKit.
final class NotchGeometryTests: XCTestCase {

    // A 15-inch MacBook Air: 1710 x 1107 points with a 185 x 33.5 notch.
    let mac = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                         safeTop: 33.5,
                         topLeft: CGRect(x: 0, y: 1073.5, width: 762.5, height: 33.5),
                         topRight: CGRect(x: 947.5, y: 1073.5, width: 762.5, height: 33.5))

    // An external display to the right of it, without a notch.
    let plain = ScreenInfo(frame: CGRect(x: 1710, y: 200, width: 1920, height: 1080),
                           safeTop: 0, topLeft: nil, topRight: nil)

    func testNotchRect() {
        XCTAssertEqual(NotchGeometry.notchRect(mac), CGRect(x: 762.5, y: 1073.5, width: 185, height: 33.5))
    }

    // The MacBook's screen is not always at (0, 0): an external display
    // can sit to its left or below it. The notch must be found on the
    // MacBook's screen whichever way macOS reports the two side areas
    // (measured from the screen's own corner, or from the main screen's).
    func testNotchRectOnScreenAwayFromOrigin() {
        let frame = CGRect(x: -1710, y: 300, width: 1710, height: 1107)
        let expected = CGRect(x: -947.5, y: 1373.5, width: 185, height: 33.5)

        let local = ScreenInfo(frame: frame, safeTop: 33.5,
                               topLeft: CGRect(x: 0, y: 1073.5, width: 762.5, height: 33.5),
                               topRight: CGRect(x: 947.5, y: 1073.5, width: 762.5, height: 33.5))
        XCTAssertEqual(NotchGeometry.notchRect(local), expected)

        let global = ScreenInfo(frame: frame, safeTop: 33.5,
                                topLeft: CGRect(x: -1710, y: 1373.5, width: 762.5, height: 33.5),
                                topRight: CGRect(x: -762.5, y: 1373.5, width: 762.5, height: 33.5))
        XCTAssertEqual(NotchGeometry.notchRect(global), expected)
    }

    func testNoNotchWithoutInset() {
        XCTAssertNil(NotchGeometry.notchRect(plain))
    }

    func testNoNotchWithoutSideAreas() {
        let odd = ScreenInfo(frame: mac.frame, safeTop: 33.5, topLeft: nil, topRight: nil)
        XCTAssertNil(NotchGeometry.notchRect(odd))
    }

    func testPanelFrame() {
        XCTAssertEqual(NotchGeometry.panelFrame(mac), CGRect(x: 570, y: 748, width: 570, height: 359))
    }

    func testPictureRect() {
        let picture = NotchGeometry.pictureRect(panelSize: CGSize(width: 570, height: 359))
        XCTAssertEqual(picture, CGRect(x: 10, y: 10, width: 550, height: 309))
        // The picture ends a small gap below the notch, so the notch never covers it.
        let notchBottom = 359 - 33.5
        XCTAssertGreaterThanOrEqual(notchBottom - picture.maxY, NotchGeometry.gapBelowNotch)
    }

    // Window frames are whole numbers, and the click area stays inside the notch.
    func testClickRect() {
        let notch = CGRect(x: 762.5, y: 1073.5, width: 185, height: 33.5)
        XCTAssertEqual(NotchGeometry.clickRect(notch: notch), CGRect(x: 767, y: 1077, width: 176, height: 30))
    }

    // Without a notch the panel drops from the top centre of that screen.
    func testFallbackOnPlainScreen() {
        XCTAssertEqual(NotchGeometry.originRect(plain), CGRect(x: 2577.5, y: 1279, width: 185, height: 1))
        XCTAssertEqual(NotchGeometry.panelFrame(plain), CGRect(x: 2350, y: 915, width: 640, height: 365))
    }

    // On a very narrow screen the panel is as wide as the notch and stays on the screen.
    func testNarrowScreen() {
        let narrow = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 400, height: 300),
                                safeTop: 30,
                                topLeft: CGRect(x: 0, y: 270, width: 107.5, height: 30),
                                topRight: CGRect(x: 292.5, y: 270, width: 107.5, height: 30))
        let panel = NotchGeometry.panelFrame(narrow)
        XCTAssertEqual(panel.width, 185)
        XCTAssertTrue(narrow.frame.contains(panel))
        XCTAssertEqual(panel.maxY, 300)
    }

    // On a screen away from (0, 0) the panel is on that screen, centred
    // under its notch.
    func testPanelOnScreenAwayFromOrigin() {
        let left = ScreenInfo(frame: CGRect(x: -1710, y: 300, width: 1710, height: 1107),
                              safeTop: 33.5,
                              topLeft: CGRect(x: 0, y: 1073.5, width: 762.5, height: 33.5),
                              topRight: CGRect(x: 947.5, y: 1073.5, width: 762.5, height: 33.5))
        let panel = NotchGeometry.panelFrame(left)
        XCTAssertEqual(panel, CGRect(x: -1140, y: 1048, width: 570, height: 359))
        XCTAssertTrue(left.frame.contains(panel))
    }

    func testNotchScreenPicksTheOneWithANotch() {
        XCTAssertEqual(NotchGeometry.notchScreen([plain, mac]), mac)
        XCTAssertNil(NotchGeometry.notchScreen([plain]))
        XCTAssertNil(NotchGeometry.notchScreen([]))
    }
}
