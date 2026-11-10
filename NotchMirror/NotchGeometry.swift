import AppKit

// The facts about one screen that the geometry needs. Kept as plain numbers
// so the rules below can be checked by tests without a real screen.
struct ScreenInfo: Equatable {
    // The whole screen, in AppKit coordinates (y grows upwards).
    let frame: CGRect
    // The height of the notch; 0 on a screen without one.
    let safeTop: CGFloat
    // The menu bar areas to the left and right of the notch, if there is one.
    let topLeft: CGRect?
    let topRight: CGRect?
}

extension ScreenInfo {
    // Reads the facts from a real screen.
    init(_ screen: NSScreen) {
        self.init(frame: screen.frame,
                  safeTop: screen.safeAreaInsets.top,
                  topLeft: screen.auxiliaryTopLeftArea,
                  topRight: screen.auxiliaryTopRightArea)
    }
}

// Works out where everything goes. Nothing in here touches a window,
// so every rule can be checked by a test.
enum NotchGeometry {

    // Black margin left, right and below the picture.
    static let margin: CGFloat = 10

    // Distance between the notch's lower edge and the picture.
    static let gapBelowNotch: CGFloat = 6

    // On a screen without a notch the panel grows out of a thin strip this wide.
    static let fallbackOriginWidth: CGFloat = 185

    // The notch: the gap between the two menu bar areas at the top.
    // nil if the screen has no notch.
    static func notchRect(_ s: ScreenInfo) -> CGRect? {
        guard s.safeTop > 0, let left = s.topLeft, let right = s.topRight else { return nil }
        return CGRect(x: left.maxX, y: s.frame.maxY - s.safeTop,
                      width: right.minX - left.maxX, height: s.safeTop)
    }

    // Where the animation starts and ends: the notch, or a thin strip at
    // the top centre of a screen without one.
    static func originRect(_ s: ScreenInfo) -> CGRect {
        if let notch = notchRect(s) { return notch }
        return CGRect(x: s.frame.midX - fallbackOriginWidth / 2, y: s.frame.maxY - 1,
                      width: fallbackOriginWidth, height: 1)
    }

    // The open panel: a third of the screen wide, hanging from the top
    // edge, centred on the notch.
    static func panelFrame(_ s: ScreenInfo) -> CGRect {
        let origin = originRect(s)
        let topInset = notchRect(s)?.height ?? 0

        var width = max(origin.width, (s.frame.width / 3).rounded())
        width = min(width, s.frame.width)
        // Windows sit on whole points, so the height is rounded up.
        let height = (topInset + gapBelowNotch + pictureHeight(panelWidth: width) + margin).rounded(.up)

        // Centre on the notch, then push back inside the screen if needed.
        var x = origin.midX - width / 2
        x = min(max(x, s.frame.minX), s.frame.maxX - width)
        return CGRect(x: x, y: s.frame.maxY - height, width: width, height: height)
    }

    // The picture inside the panel, in the panel's own coordinates
    // (its bottom-left corner is 0, 0). The picture is 16:9.
    static func pictureRect(panelSize: CGSize) -> CGRect {
        CGRect(x: margin, y: margin,
               width: panelSize.width - 2 * margin,
               height: pictureHeight(panelWidth: panelSize.width))
    }

    // The area that reacts to clicks: a little smaller than the notch, so
    // nothing peeks out past the notch's rounded lower corners.
    // Windows sit on whole points, so the edges are rounded inwards.
    static func clickRect(notch: CGRect) -> CGRect {
        let left = (notch.minX + 4).rounded(.up)
        let right = (notch.maxX - 4).rounded(.down)
        let bottom = (notch.minY + 3).rounded(.up)
        return CGRect(x: left, y: bottom, width: right - left, height: notch.maxY - bottom)
    }

    // The first screen that has a notch, if any.
    static func notchScreen(_ screens: [ScreenInfo]) -> ScreenInfo? {
        screens.first { notchRect($0) != nil }
    }

    private static func pictureHeight(panelWidth: CGFloat) -> CGFloat {
        ((panelWidth - 2 * margin) * 9 / 16).rounded()
    }
}
