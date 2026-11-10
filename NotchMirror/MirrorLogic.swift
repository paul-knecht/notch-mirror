import Foundation

// Whether the app may use the camera.
enum CameraAccess {
    case notAsked   // macOS has not asked the user yet
    case granted
    case denied
}

// What the panel shows.
enum MirrorContent: Equatable {
    case picture            // the live camera picture
    case waitingForAccess   // macOS is asking the user right now
    case noAccess           // the user said no
    case noCamera           // there is no built-in camera
}

// One thing the app has to do. The logic below only decides; the
// AppDelegate carries the decisions out.
enum MirrorAction: Equatable {
    case showPanel(MirrorContent)    // open the panel with this content
    case updatePanel(MirrorContent)  // change the content of the open panel
    case askForAccess                // let macOS ask for camera access
    case startCamera
    case stopCamera
    case hidePanel
}

// What we need to know about a camera to choose one.
struct CameraInfo {
    let isBuiltInWideAngle: Bool
    let isContinuity: Bool    // an iPhone offering itself as a camera
}

// Decides what happens when the mirror is opened or closed. It never
// touches a window or the camera itself, so every rule can be checked by
// a test. The most important rule: closing always stops the camera.
struct MirrorLogic {

    private(set) var isOpen = false

    // True from the moment macOS is asked until the user has answered.
    private(set) var isWaitingForAccess = false

    // The user wants to see the mirror.
    mutating func open(access: CameraAccess, hasCamera: Bool) -> [MirrorAction] {
        if isOpen { return [] }
        isOpen = true

        switch access {
        case .granted:
            return hasCamera ? [.showPanel(.picture), .startCamera] : [.showPanel(.noCamera)]
        case .denied:
            return [.showPanel(.noAccess)]
        case .notAsked:
            isWaitingForAccess = true
            return [.showPanel(.waitingForAccess), .askForAccess]
        }
    }

    // The user has answered macOS's question about the camera.
    mutating func accessAnswered(granted: Bool, hasCamera: Bool) -> [MirrorAction] {
        isWaitingForAccess = false
        // The mirror was closed in the meantime: leave the camera off.
        if !isOpen { return [] }

        if !granted { return [.updatePanel(.noAccess)] }
        return hasCamera ? [.updatePanel(.picture), .startCamera] : [.updatePanel(.noCamera)]
    }

    // The user wants the mirror gone.
    mutating func close() -> [MirrorAction] {
        if !isOpen { return [] }
        isOpen = false
        // Always both, so the camera can never be left running.
        return [.hidePanel, .stopCamera]
    }

    // Does a click somewhere else close the mirror? Not while macOS is
    // asking for camera access: answering that is itself a click elsewhere.
    var closesOnOutsideClick: Bool {
        isOpen && !isWaitingForAccess
    }

    // The position of the camera to use: the Mac's own, never an iPhone.
    static func pickCamera(_ cameras: [CameraInfo]) -> Int? {
        cameras.firstIndex { $0.isBuiltInWideAngle && !$0.isContinuity }
    }
}
