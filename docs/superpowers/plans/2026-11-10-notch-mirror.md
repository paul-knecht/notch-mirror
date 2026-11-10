# NotchMirror Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS app that shows the camera picture as a mirror in a black panel that grows out of the notch, opened either by clicking the notch or by a menu bar icon.

**Architecture:** Two borderless panels above the menu bar: the mirror panel (a full-size view revealed by a growing mask) and an invisible click area on the notch. All decisions (where things go, what is visible, when the camera starts and stops) are made by small pure types that the tests cover; AppKit and AVFoundation code only carries them out.

**Tech Stack:** Swift 5, AppKit, Core Animation, AVFoundation, SwiftUI for the settings window only, ServiceManagement, XCTest. No third-party libraries.

**Spec:** `docs/superpowers/specs/2026-11-10-notch-mirror-design.md`

## Global Constraints

- Repo `notch-mirror`, branch `feature/notch-mirror`; merge into `main` locally with `--no-ff` at the end. No remotes, no pushing.
- Commits use the repo's configured no-reply identity and end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. No personal names or paths in any file or commit.
- Deployment target macOS 14.0, App Sandbox off, `LSUIElement = YES`, bundle identifier `local.notchmirror`, signed to run locally. The camera usage text is already in the project file.
- The scaffold already exists and is uncommitted: `NotchMirror.xcodeproj` (app target, hosted test target `NotchMirrorTests`, shared scheme), `NotchMirror/main.swift`, `SingleInstance.swift`, `LoginItem.swift`, their two test files, `scripts/install.sh`.
- Build: `xcodebuild -project NotchMirror.xcodeproj -scheme NotchMirror -derivedDataPath build build`. Test: the same with `test`.
- Tests never switch the camera on, never touch the real preferences, the login items or other running copies. `isRunningTests` is `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil`.
- Simple code: small files, a comment above each type and each non-obvious function saying what it is for.
- After each task: explain in plain language what was done and why, and each commit in one sentence.
- Before the first step that makes macOS ask for camera access (Task 8), tell the user what it is for.

## Review Focus

1. The mirror is closed while macOS is still asking for camera access, and access is granted afterwards → the camera never starts. (Task 4 test.)
2. Open, close and open again in quick succession → after the last action the camera state matches the panel: on if open, off if closed. (Task 4 test.)
3. The user clicks elsewhere to answer the camera question → the mirror stays open. (Task 4 test.)
4. Notch mode on a setup without a notch (lid closed, external display) → the menu bar icon appears so the app stays reachable. (Task 3 test, Task 6 smoke test.)
5. A screen that does not start at (0, 0), or one narrower than three notches → the panel is still centred, on that screen, and never wider than it. (Task 2 tests.)

## File Structure

| File | Responsibility |
|---|---|
| `NotchMirror/NotchGeometry.swift` | Pure: where the notch, the panel, the picture and the click area go |
| `NotchMirror/MirrorSettings.swift` | The stored setting and the pure rules for what is visible |
| `NotchMirror/MirrorLogic.swift` | Pure: what must happen on open, close and the camera answer |
| `NotchMirror/MirrorCamera.swift` | The camera session and its preview layer |
| `NotchMirror/MirrorPanel.swift` | The panel window and its view (shape, picture, message, animation) |
| `NotchMirror/NotchClickArea.swift` | The invisible window on the notch |
| `NotchMirror/SettingsView.swift` | The small settings window's content |
| `NotchMirror/AppDelegate.swift` | Ties everything together; menu; system notifications |
| `NotchMirrorTests/*Tests.swift` | One file per tested type, plus `SmokeTests.swift` |

---

### Task 1: The scaffold builds

**Files:** Create `NotchMirror/AppDelegate.swift`, `NotchMirrorTests/SmokeTests.swift`.

**Produces:** `@MainActor class AppDelegate: NSObject, NSApplicationDelegate` with `let isRunningTests: Bool`.

- [ ] `AppDelegate` with an empty `applicationDidFinishLaunching` that returns early when `isRunningTests`, and otherwise calls `SingleInstance.quitOlderCopies()`.
- [ ] `SmokeTests.testAppDelegateExists`: `XCTAssertTrue(NSApp.delegate is AppDelegate)`.
- [ ] Run the test command. Expected: `** TEST SUCCEEDED **` (the copied SingleInstance and LoginItem tests pass too).
- [ ] Commit "Add NotchMirror app skeleton".

### Task 2: Notch geometry

**Files:** Create `NotchMirror/NotchGeometry.swift`; test `NotchMirrorTests/NotchGeometryTests.swift`.

**Produces:**
- `struct ScreenInfo: Equatable { let frame: CGRect; let safeTop: CGFloat; let topLeft: CGRect?; let topRight: CGRect? }` plus `init(_ screen: NSScreen)`.
- `enum NotchGeometry` with constants `margin: CGFloat = 10`, `gapBelowNotch: CGFloat = 6`, `fallbackOriginWidth: CGFloat = 185`, and:
  - `static func notchRect(_ s: ScreenInfo) -> CGRect?` — nil unless `safeTop > 0` and both side areas exist; otherwise x from `topLeft.maxX` to `topRight.minX`, height `safeTop`, top edge at `frame.maxY`.
  - `static func originRect(_ s: ScreenInfo) -> CGRect` — the notch, or a strip `fallbackOriginWidth` × 1 at the top centre of the frame. This is where the animation starts and ends.
  - `static func panelFrame(_ s: ScreenInfo) -> CGRect` — width `max(originRect.width, (frame.width / 3).rounded())`, never more than `frame.width`; height `topInset + gapBelowNotch + pictureHeight + margin` where `topInset` is the notch height (0 without a notch) and `pictureHeight = ((width - 2 * margin) * 9 / 16).rounded()`; centred on `originRect.midX`, pushed back inside the frame if needed; top edge at `frame.maxY`.
  - `static func pictureRect(panelSize: CGSize) -> CGRect` — in the panel's own coordinates (origin bottom-left): x `margin`, y `margin`, width `panelSize.width - 2 * margin`, height `(width * 9 / 16).rounded()`.
  - `static func clickRect(notch: CGRect) -> CGRect` — the notch inset by 4 left and right and 3 at the bottom, top edge unchanged.
  - `static func notchScreen(_ screens: [ScreenInfo]) -> ScreenInfo?` — the first with a notch.

- [ ] **Failing tests** with `mac = ScreenInfo(frame: (0,0,1710,1107), safeTop: 33.5, topLeft: (0,1073.5,762.5,33.5), topRight: (947.5,1073.5,762.5,33.5))`:
  - `testNotchRect`: `(762.5, 1073.5, 185, 33.5)`.
  - `testNoNotchWithoutInset` and `testNoNotchWithoutSideAreas`: nil.
  - `testPanelFrame`: `(570, 748.5, 570, 358.5)`.
  - `testPictureRect`: for size 570 × 358.5 → `(10, 10, 550, 309)`; its top edge (319) is `gapBelowNotch` below the notch's bottom edge (358.5 − 33.5 = 325).
  - `testClickRect`: `(766.5, 1076.5, 177, 30.5)`.
  - `testFallbackOnPlainScreen`: `ScreenInfo(frame: (1710,200,1920,1080), safeTop: 0, nil, nil)` → origin `(2577.5, 1279, 185, 1)`, panel `(2350, 915, 640, 365)`.
  - `testNarrowScreen`: frame width 400 with a 185 notch in the middle → panel width 185, inside the frame.
  - `testNotchScreenPicksTheOneWithANotch`: `[plain, mac]` → `mac`; `[plain]` → nil.
- [ ] Fail, implement, pass. Commit "Add notch geometry".

### Task 3: Settings

**Files:** Create `NotchMirror/MirrorSettings.swift`; test `NotchMirrorTests/MirrorSettingsTests.swift`.

**Produces:**
- `enum Trigger: String { case notch, menuBarIcon }`
- `struct MirrorSettings { init(defaults: UserDefaults); var trigger: Trigger { get nonmutating set }; var didShowWelcome: Bool { get nonmutating set }; var didSetUpLoginItem: Bool { get nonmutating set } }` — keys `"trigger"`, `"didShowWelcome"`, `"didSetUpLoginItem"`; a missing or unknown trigger value reads as `.notch`.
- `static func showsMenuBarIcon(trigger: Trigger, notchAvailable: Bool) -> Bool` — true for `.menuBarIcon`, and for `.notch` without a notch.
- `static func showsNotchArea(trigger: Trigger, notchAvailable: Bool) -> Bool` — true only for `.notch` with a notch.

- [ ] **Failing tests** on a throwaway `UserDefaults(suiteName:)` removed in `tearDown`: default is `.notch`; a set value is read back by a second `MirrorSettings` on the same suite; garbage `"xyz"` reads as `.notch`; the two flags default to false and persist; the four combinations of the two visibility functions.
- [ ] Fail, implement, pass. Commit "Add settings".

### Task 4: Mirror logic and camera choice

**Files:** Create `NotchMirror/MirrorLogic.swift`; test `NotchMirrorTests/MirrorLogicTests.swift`.

**Produces:**
- `enum CameraAccess { case notAsked, granted, denied }`
- `enum MirrorContent: Equatable { case picture, waitingForAccess, noAccess, noCamera }`
- `enum MirrorAction: Equatable { case showPanel(MirrorContent), updatePanel(MirrorContent), askForAccess, startCamera, stopCamera, hidePanel }`
- `struct MirrorLogic { private(set) var isOpen = false; private(set) var isWaitingForAccess = false; mutating func open(access: CameraAccess, hasCamera: Bool) -> [MirrorAction]; mutating func accessAnswered(granted: Bool, hasCamera: Bool) -> [MirrorAction]; mutating func close() -> [MirrorAction]; var closesOnOutsideClick: Bool { get } }`
- `struct CameraInfo { let isBuiltInWideAngle: Bool; let isContinuity: Bool }` and `static func MirrorLogic.pickCamera(_ cameras: [CameraInfo]) -> Int?` — index of the first built-in wide-angle camera that is not a Continuity Camera.

Rules: `open` while open returns `[]`. `open` with `.granted` and a camera → `[.showPanel(.picture), .startCamera]`; `.granted` without a camera → `[.showPanel(.noCamera)]`; `.denied` → `[.showPanel(.noAccess)]`; `.notAsked` → `[.showPanel(.waitingForAccess), .askForAccess]` and `isWaitingForAccess = true`. `accessAnswered` clears the waiting flag; if the mirror is no longer open it returns `[]`; otherwise granted with a camera → `[.updatePanel(.picture), .startCamera]`, granted without → `[.updatePanel(.noCamera)]`, not granted → `[.updatePanel(.noAccess)]`. `close` while closed returns `[]`; otherwise `[.hidePanel, .stopCamera]` (always both, so the camera can never be left on). `closesOnOutsideClick` is `isOpen && !isWaitingForAccess`.

- [ ] **Failing tests**, one per rule above, plus the Review Focus cases: `testClosedDuringQuestionNeverStartsCamera` (open notAsked → close → accessAnswered(granted: true) returns `[]`), `testOpenCloseOpen` (the action lists, in order, end with `.startCamera` and `isOpen == true`), `testOutsideClickIgnoredWhileWaiting`, `testCloseAlwaysStopsCamera` (also after `.noAccess`), and `pickCamera` with `[continuity external, built-in]` → 1, `[continuity only]` → nil, `[]` → nil.
- [ ] Fail, implement, pass. Commit "Add mirror logic".

### Task 5: Camera and panel

**Files:** Create `NotchMirror/MirrorCamera.swift`, `NotchMirror/MirrorPanel.swift`.

**Consumes:** `NotchGeometry`, `MirrorContent`, `MirrorLogic.pickCamera`, `CameraAccess`.

**Produces:**
- `final class MirrorCamera { var access: CameraAccess { get }; var hasCamera: Bool { get }; let previewLayer: AVCaptureVideoPreviewLayer; func askForAccess(_ done: @escaping @MainActor (Bool) -> Void); func start(); func stop() }` — discovers `[.builtInWideAngleCamera, .external]` video devices and picks with `pickCamera`; configures the session once, lazily; `start`/`stop` run on one private serial queue; preview is aspect-fill and mirrored (`automaticallyAdjustsVideoMirroring = false`, `isVideoMirrored = true`).
- `final class MirrorPanel: NSPanel { init(); var onOpenPrivacySettings: (() -> Void)?; func setPreviewLayer(_ layer: CALayer); func show(_ content: MirrorContent); func open(on screen: ScreenInfo, animated: Bool); func close(animated: Bool, completion: @escaping () -> Void); override var canBecomeKey: Bool }` — borderless, non-activating, clear background, no shadow, level `mainMenu + 3`, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`. Its content view is layer-backed with: a black background layer; the preview layer at `pictureRect` with corner radius 10; a centred white label and a button "Open Privacy Settings" (button only for `.noAccess`); and a mask layer, anchored top centre, black, bottom corners rounded with radius 18. `open` sets the window to `panelFrame`, sets the mask to the origin rect's size and animates it to full size in 0.3 s ease-out; `close` animates back in 0.2 s ease-in, then orders the window out and calls `completion`. With `animated: false` both jump.

Message texts: `.waitingForAccess` "Waiting for camera access…", `.noAccess` "NotchMirror has no access to the camera.", `.noCamera` "No built-in camera found.", `.picture` no label.

- [ ] Implement both. The build command succeeds with no warnings from these files.
- [ ] Commit "Add camera and mirror panel".

### Task 6: Click area, wiring and menu

**Files:** Create `NotchMirror/NotchClickArea.swift`; modify `NotchMirror/AppDelegate.swift`; extend `NotchMirrorTests/SmokeTests.swift`.

**Produces:**
- `final class NotchClickArea: NSPanel { init(); var onClick: (() -> Void)?; var menuProvider: (() -> NSMenu)?; func place(over notch: CGRect) }` — borderless, non-activating, black, opaque, same level and Space behaviour as the panel; its view calls `onClick` on left mouse up and pops up the menu on right mouse down.
- On `AppDelegate`: `var settings: MirrorSettings` (a throwaway suite named `local.notchmirror.tests` while testing, cleared at launch); `var statusItem: NSStatusItem!`; `let clickArea`, `let panel`, `var logic = MirrorLogic()`; `func applyVisibility(notchScreen: ScreenInfo?)`; `func setTrigger(_ t: Trigger)`; `func toggleMirror()`; `func closeMirror()`; `func buildMenu() -> NSMenu`; `func perform(_ actions: [MirrorAction])`.

Behaviour: the status item uses the symbol `person.crop.square`, toggles on left click and shows the menu on right click. `applyVisibility` shows or hides the status item and the click area using the two `MirrorSettings` functions, and places the click area. `perform` carries out actions; while testing, `.askForAccess` and `.startCamera` and `.stopCamera` are skipped and animations are off. A local key monitor closes on esc (key code 53) when the panel is key; a global mouse-down monitor closes when `logic.closesOnOutsideClick`. The mirror also closes on `NSWorkspace.willSleepNotification`, `NSWorkspace.screensDidSleepNotification`, the distributed notification `com.apple.screenIsLocked`, `NSApplication.didChangeScreenParametersNotification` (followed by `applyVisibility`), and `applicationWillTerminate` (which also stops the camera directly). Login item set-up as in ClassCountdown, using `settings.didSetUpLoginItem`.

Menu, exact titles in order: "Open from" (disabled), "Notch", "Menu Bar Icon" (both indented by 1, the current one checked), separator, "Start at Login" (checked when enabled), separator, "Quit NotchMirror" (key equivalent `q`).

- [ ] **Smoke tests:** `testMenuTitlesAndCheckmark`; `testIconModeShowsIconAndHidesNotchArea`; `testNotchModeWithNotchShowsAreaAndHidesIcon` (pass the Task 2 `mac` screen); `testNotchModeWithoutNotchShowsIcon` (pass nil); `testToggleOpensAndClosesPanel` (`panel.isVisible` true then false); `testSetTriggerPersists` (a new `MirrorSettings` on the same suite reads it). `tearDown` closes the mirror and resets the trigger to `.notch`.
- [ ] Fail, implement, pass. Commit "Wire up notch click area, menu bar icon and menu".

### Task 7: Settings window and first launch

**Files:** Create `NotchMirror/SettingsView.swift`; modify `NotchMirror/AppDelegate.swift`; extend `SmokeTests.swift`.

**Produces:** `struct SettingsView: View` with `showsWelcome: Bool`, `trigger: Trigger`, `startAtLogin: Bool`, `access: CameraAccess`, and closures `setTrigger`, `setStartAtLogin`, `openPrivacySettings`, `quit`; on `AppDelegate`: `func showSettings(welcome: Bool)`, `func openPrivacySettings()` (opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Camera`), `applicationShouldHandleReopen` → `showSettings(welcome: false)`.

Content: when `showsWelcome`, the line "Click the notch to open the mirror. Right-click it for these settings."; a picker "Open from" with "Notch" and "Menu Bar Icon"; a toggle "Start at Login"; one line on camera access ("Camera access: granted", "not asked yet — macOS asks the first time you open the mirror", or "denied" with the button "Open Privacy Settings"); a button "Quit NotchMirror". On the first non-test launch (`!settings.didShowWelcome`) the window opens with the welcome line and the flag is set.

- [ ] **Smoke test** `testSettingsWindowOpens`: after `showSettings(welcome: false)`, a visible window titled "NotchMirror" exists; close it in `tearDown`.
- [ ] Fail, implement, pass. Commit "Add settings window and first-launch hint".

### Task 8: README, install, review, hand checks, merge

- [ ] Write `README.md` (what it does, the two ways to open it, install, privacy: nothing is saved or sent, known limits) and copy the MIT `LICENSE` from a sibling project only if the user asks to publish; otherwise no licence file.
- [ ] Run the full tests. Dispatch one independent reviewer over the branch diff against the spec; fix what it finds that is real; run the tests again.
- [ ] Tell the user that the next step installs the app and that opening the mirror for the first time makes macOS ask for camera access, and why. Then run `./scripts/install.sh` and confirm the process is running.
- [ ] Hand checks with the user: the welcome window appears once; clicking the notch opens the mirror out of the notch; the picture is mirrored; esc, a click elsewhere and a second click on the notch each close it and the green light goes out; right-click on the notch shows the menu; switching to "Menu Bar Icon" shows the icon and the notch stops reacting; quit and start again: the choice is kept.
- [ ] Commit, switch to `main`, `git merge --no-ff feature/notch-mirror`, delete the branch, show `git log --oneline --graph`. Tell the user what was not verified.
