import AVFoundation

// The Mac's built-in camera and the layer that shows its picture.
//
// A "session" is AVFoundation's word for a running camera. While it runs,
// the green light next to the camera is on; when it stops, the light goes out.
final class MirrorCamera {

    private let session = AVCaptureSession()

    // Starting and stopping takes a moment, so it happens on this
    // background queue, one request after the other. Because they keep
    // their order, the camera always ends up in the state asked for last.
    private let queue = DispatchQueue(label: "local.notchmirror.camera")

    // True once the camera has been connected to the session.
    private var isConfigured = false

    // The layer that shows the live picture. The panel puts it on screen.
    let previewLayer: AVCaptureVideoPreviewLayer

    init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        // Fill the whole rectangle, cropping the edges if the shapes differ.
        previewLayer.videoGravity = .resizeAspectFill
    }

    // Whether the app may use the camera.
    var access: CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    // Is there a built-in camera at all?
    var hasCamera: Bool {
        builtInCamera() != nil
    }

    // Lets macOS ask the user for camera access, and reports the answer.
    func askForAccess(_ done: @escaping @MainActor (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in done(granted) }
        }
    }

    // Switches the camera on.
    func start() {
        queue.async { [self] in
            configureIfNeeded()
            if isConfigured && !session.isRunning {
                session.startRunning()
            }
        }
    }

    // Switches the camera off.
    func stop() {
        queue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // The Mac's own camera. An iPhone that offers itself as a camera is
    // listed too, and is skipped.
    private func builtInCamera() -> AVCaptureDevice? {
        let found = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video, position: .unspecified).devices
        let infos = found.map {
            CameraInfo(isBuiltInWideAngle: $0.deviceType == .builtInWideAngleCamera,
                       isContinuity: $0.isContinuityCamera)
        }
        guard let index = MirrorLogic.pickCamera(infos) else { return nil }
        return found[index]
    }

    // Connects the camera to the session, the first time it is needed.
    private func configureIfNeeded() {
        if isConfigured { return }
        guard let camera = builtInCamera(),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }

        session.beginConfiguration()
        session.sessionPreset = .high
        session.addInput(input)
        session.commitConfiguration()
        isConfigured = true

        // Flip the picture left to right, like a real mirror.
        DispatchQueue.main.async { [self] in
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }
}
