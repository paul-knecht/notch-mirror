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

    func testNoNotchWithoutInset() {
        XCTAssertNil(NotchGeometry.notchRect(plain))
    }

    func testNoNotchWithoutSideAreas() {
        let odd = ScreenInfo(frame: mac.frame, safeTop: 33.5, topLeft: nil, topRight: nil)
        XCTAssertNil(NotchGeometry.notchRect(odd))
    }

    func testPanelFrame() {
        XCTAssertEqual(NotchGeometry.panelFrame(mac), CGRect(x: 570, y: 748.5, width: 570, height: 358.5))
    }

    func testPictureRect() {
        let picture = NotchGeometry.pictureRect(panelSize: CGSize(width: 570, height: 358.5))
        XCTAssertEqual(picture, CGRect(x: 10, y: 10, width: 550, height: 309))
        // The picture ends a small gap below the notch, so the notch never covers it.
        let notchBottom = 358.5 - 33.5
        XCTAssertEqual(notchBottom - picture.maxY, NotchGeometry.gapBelowNotch)
    }

    func testClickRect() {
        let notch = CGRect(x: 762.5, y: 1073.5, width: 185, height: 33.5)
        XCTAssertEqual(NotchGeometry.clickRect(notch: notch), CGRect(x: 766.5, y: 1076.5, width: 177, height: 30.5))
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

    // A panel never sticks out over the side of its screen.
    func testPanelIsPushedBackInside() {
        let offCentre = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 600, height: 400),
                                   safeTop: 30,
                                   topLeft: CGRect(x: 0, y: 370, width: 20, height: 30),
                                   topRight: CGRect(x: 80, y: 370, width: 520, height: 30))
        let panel = NotchGeometry.panelFrame(offCentre)
        XCTAssertEqual(panel.minX, 0)
        XCTAssertEqual(panel.width, 200)
    }

    func testNotchScreenPicksTheOneWithANotch() {
        XCTAssertEqual(NotchGeometry.notchScreen([plain, mac]), mac)
        XCTAssertNil(NotchGeometry.notchScreen([plain]))
        XCTAssertNil(NotchGeometry.notchScreen([]))
    }
}
