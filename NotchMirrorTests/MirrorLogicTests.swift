import XCTest
@testable import NotchMirror

// Checks what must happen when the mirror is opened and closed, above all
// that the camera can never be left running.
final class MirrorLogicTests: XCTestCase {

    // MARK: - Opening

    func testOpenWithAccessShowsPictureAndStartsCamera() {
        var logic = MirrorLogic()
        XCTAssertEqual(logic.open(access: .granted, hasCamera: true), [.showPanel(.picture), .startCamera])
        XCTAssertTrue(logic.isOpen)
    }

    func testOpenWithoutCameraShowsMessage() {
        var logic = MirrorLogic()
        XCTAssertEqual(logic.open(access: .granted, hasCamera: false), [.showPanel(.noCamera)])
    }

    func testOpenWhenDeniedShowsMessageAndNeverStartsCamera() {
        var logic = MirrorLogic()
        XCTAssertEqual(logic.open(access: .denied, hasCamera: true), [.showPanel(.noAccess)])
    }

    func testFirstOpenAsksForAccess() {
        var logic = MirrorLogic()
        XCTAssertEqual(logic.open(access: .notAsked, hasCamera: true), [.showPanel(.waitingForAccess), .askForAccess])
        XCTAssertTrue(logic.isWaitingForAccess)
    }

    func testOpenWhileOpenDoesNothing() {
        var logic = MirrorLogic()
        _ = logic.open(access: .granted, hasCamera: true)
        XCTAssertEqual(logic.open(access: .granted, hasCamera: true), [])
    }

    // MARK: - The answer to the camera question

    func testGrantedWhileOpenStartsCamera() {
        var logic = MirrorLogic()
        _ = logic.open(access: .notAsked, hasCamera: true)
        XCTAssertEqual(logic.accessAnswered(granted: true, hasCamera: true), [.updatePanel(.picture), .startCamera])
        XCTAssertFalse(logic.isWaitingForAccess)
    }

    func testGrantedWithoutCameraShowsMessage() {
        var logic = MirrorLogic()
        _ = logic.open(access: .notAsked, hasCamera: false)
        XCTAssertEqual(logic.accessAnswered(granted: true, hasCamera: false), [.updatePanel(.noCamera)])
    }

    func testDeniedWhileOpenShowsMessage() {
        var logic = MirrorLogic()
        _ = logic.open(access: .notAsked, hasCamera: true)
        XCTAssertEqual(logic.accessAnswered(granted: false, hasCamera: true), [.updatePanel(.noAccess)])
    }

    // The mirror was closed while macOS was still asking. Saying yes
    // afterwards must not switch the camera on.
    func testClosedDuringQuestionNeverStartsCamera() {
        var logic = MirrorLogic()
        _ = logic.open(access: .notAsked, hasCamera: true)
        _ = logic.close()
        XCTAssertEqual(logic.accessAnswered(granted: true, hasCamera: true), [])
        XCTAssertFalse(logic.isWaitingForAccess)
    }

    // MARK: - Closing

    func testCloseHidesPanelAndStopsCamera() {
        var logic = MirrorLogic()
        _ = logic.open(access: .granted, hasCamera: true)
        XCTAssertEqual(logic.close(), [.hidePanel, .stopCamera])
        XCTAssertFalse(logic.isOpen)
    }

    // Closing always stops the camera, even if it was never started.
    func testCloseAlwaysStopsCamera() {
        var logic = MirrorLogic()
        _ = logic.open(access: .denied, hasCamera: true)
        XCTAssertEqual(logic.close(), [.hidePanel, .stopCamera])
    }

    func testCloseWhileClosedDoesNothing() {
        var logic = MirrorLogic()
        XCTAssertEqual(logic.close(), [])
    }

    func testOpenCloseOpen() {
        var logic = MirrorLogic()
        var actions = logic.open(access: .granted, hasCamera: true)
        actions += logic.close()
        actions += logic.open(access: .granted, hasCamera: true)
        XCTAssertEqual(actions, [.showPanel(.picture), .startCamera,
                                 .hidePanel, .stopCamera,
                                 .showPanel(.picture), .startCamera])
        XCTAssertTrue(logic.isOpen)
    }

    // MARK: - Clicks elsewhere

    func testOutsideClickClosesWhenOpen() {
        var logic = MirrorLogic()
        XCTAssertFalse(logic.closesOnOutsideClick)
        _ = logic.open(access: .granted, hasCamera: true)
        XCTAssertTrue(logic.closesOnOutsideClick)
    }

    // Answering the camera question is a click elsewhere. It must not
    // close the mirror.
    func testOutsideClickIgnoredWhileWaiting() {
        var logic = MirrorLogic()
        _ = logic.open(access: .notAsked, hasCamera: true)
        XCTAssertFalse(logic.closesOnOutsideClick)
        _ = logic.accessAnswered(granted: true, hasCamera: true)
        XCTAssertTrue(logic.closesOnOutsideClick)
    }

    // MARK: - Which camera

    func testPicksBuiltInCameraNotThePhone() {
        let phone = CameraInfo(isBuiltInWideAngle: false, isContinuity: true)
        let builtIn = CameraInfo(isBuiltInWideAngle: true, isContinuity: false)
        XCTAssertEqual(MirrorLogic.pickCamera([phone, builtIn]), 1)
        XCTAssertEqual(MirrorLogic.pickCamera([builtIn, phone]), 0)
    }

    func testNoCameraWhenOnlyThePhoneIsThere() {
        XCTAssertNil(MirrorLogic.pickCamera([CameraInfo(isBuiltInWideAngle: false, isContinuity: true)]))
        XCTAssertNil(MirrorLogic.pickCamera([CameraInfo(isBuiltInWideAngle: true, isContinuity: true)]))
        XCTAssertNil(MirrorLogic.pickCamera([]))
    }
}
