import AppKit

// The window that shows the mirror. It hangs from the top edge of the
// screen, above the menu bar, so it can cover the area around the notch.
//
// It is a "non-activating panel": it can take the esc key without
// NotchMirror becoming the active app, so the app you were in stays in front.
final class MirrorPanel: NSPanel {

    // Called when the "Open Privacy Settings" button is clicked.
    var onOpenPrivacySettings: (() -> Void)?

    // The black area; everything visible sits inside it.
    private let blackView = NSView()

    // The part of blackView that is visible. It grows out of the notch
    // when the mirror opens and shrinks back into it when it closes.
    private let maskLayer = CALayer()

    // Holds the camera picture.
    private let pictureView = NSView()

    // Text shown instead of the picture, and the button below it.
    private let messageLabel = NSTextField(labelWithString: "")
    private let settingsButton = NSButton(title: "Open Privacy Settings", target: nil, action: nil)

    // The size the mask starts from and shrinks back to (the notch's size).
    private var closedSize = CGSize.zero

    // Counts how often the panel was opened. A closing animation that ends
    // after the panel was opened again must not hide it.
    private var openCount = 0

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        // Three levels above the menu bar, so the panel can cover it.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        // Only the black shape is visible; the rest of the window is clear.
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // Show on every Space (desktop), also over full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let content = NSView()
        content.wantsLayer = true
        contentView = content

        blackView.wantsLayer = true
        blackView.layer?.backgroundColor = NSColor.black.cgColor
        content.addSubview(blackView)

        // The mask is black where blackView is visible. Its top edge stays
        // at the top of the panel (anchor point "middle of the top edge"),
        // so changing its size makes it grow downwards.
        maskLayer.backgroundColor = NSColor.black.cgColor
        maskLayer.anchorPoint = CGPoint(x: 0.5, y: 1)
        maskLayer.cornerRadius = 18
        // Round only the two bottom corners; the top sits against the screen edge.
        maskLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        blackView.layer?.mask = maskLayer

        pictureView.wantsLayer = true
        pictureView.layer?.cornerRadius = 10
        pictureView.layer?.masksToBounds = true
        blackView.addSubview(pictureView)

        messageLabel.textColor = .white
        messageLabel.alignment = .center
        messageLabel.font = .systemFont(ofSize: 13)
        blackView.addSubview(messageLabel)

        settingsButton.target = self
        settingsButton.action = #selector(settingsButtonClicked)
        settingsButton.bezelStyle = .rounded
        blackView.addSubview(settingsButton)
    }

    // Without this a borderless window refuses keyboard input (the esc key).
    override var canBecomeKey: Bool { true }

    // Puts the camera's picture layer into the panel.
    func setPreviewLayer(_ layer: CALayer) {
        pictureView.layer?.addSublayer(layer)
        layer.frame = pictureView.bounds
    }

    // Chooses what the panel shows: the picture, or a short text.
    func show(_ content: MirrorContent) {
        pictureView.isHidden = content != .picture
        messageLabel.isHidden = content == .picture
        settingsButton.isHidden = content != .noAccess
        messageLabel.stringValue = MirrorPanel.message(for: content)
    }

    // The text shown instead of the picture.
    static func message(for content: MirrorContent) -> String {
        switch content {
        case .picture: return ""
        case .waitingForAccess: return "Waiting for camera access…"
        case .noAccess: return "NotchMirror has no access to the camera."
        case .noCamera: return "No built-in camera found."
        }
    }

    // Shows the panel on the given screen, growing out of the notch.
    func open(on screen: ScreenInfo, animated: Bool) {
        openCount += 1
        let frame = NotchGeometry.panelFrame(screen)
        closedSize = NotchGeometry.originRect(screen).size
        setFrame(frame, display: true)
        layOut(size: frame.size)

        // Start at the notch's size, without animation…
        setMaskSize(closedSize, duration: 0, then: nil)
        orderFrontRegardless()
        makeKey()
        // …then grow to the full size.
        setMaskSize(frame.size, duration: animated ? 0.3 : 0, then: nil)
    }

    // Slides the panel back into the notch, then hides the window.
    func close(animated: Bool, completion: @escaping () -> Void) {
        let countWhenClosing = openCount
        setMaskSize(closedSize, duration: animated ? 0.2 : 0) { [weak self] in
            // Opened again in the meantime? Then leave it on screen.
            if let self, self.openCount == countWhenClosing {
                self.orderOut(nil)
            }
            completion()
        }
    }

    // Places the views for a panel of the given size.
    private func layOut(size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        contentView?.frame = bounds
        blackView.frame = bounds

        // The mask's anchor point (middle of its top edge) goes to the
        // middle of the panel's top edge. Layer coordinates have y growing
        // upwards, so the top is at "height".
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.position = CGPoint(x: size.width / 2, y: size.height)
        CATransaction.commit()

        let picture = NotchGeometry.pictureRect(panelSize: size)
        pictureView.frame = picture
        pictureView.layer?.sublayers?.forEach { $0.frame = pictureView.bounds }

        messageLabel.frame = CGRect(x: picture.minX, y: picture.midY, width: picture.width, height: 20)
        settingsButton.sizeToFit()
        settingsButton.frame.origin = CGPoint(x: picture.midX - settingsButton.frame.width / 2,
                                              y: picture.midY - 36)
    }

    // Changes the size of the visible part, with or without animation.
    private func setMaskSize(_ size: CGSize, duration: Double, then completion: (() -> Void)?) {
        CATransaction.begin()
        if duration == 0 {
            CATransaction.setDisableActions(true)
        } else {
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        }
        CATransaction.setCompletionBlock(completion)
        maskLayer.bounds = CGRect(origin: .zero, size: size)
        CATransaction.commit()
    }

    @objc private func settingsButtonClicked() {
        onOpenPrivacySettings?()
    }
}
