# NotchMirror — design

Date: 2026-11-10
Status: approved in conversation; the build may start

Lines marked **(Claude's call)** are defaults Claude chose. Lines marked
**(accepted default)** were shown to the user, who did not object. Everything
else is what the user asked for.

## Intent and why

The user wants a quick mirror: one action, and they see themselves through
the Mac's camera, for a glance before a call or a class. It should feel like
part of the Mac: the picture comes out of the notch and goes back into it.

The user is a beginner learning Swift, Xcode and Git through these projects,
so the code must stay simple and readable. They also want fewer icons in the
menu bar, which is why the notch itself can be the button.

## Goals (version 1)

1. Opening the mirror shows the live camera picture, flipped left to right
   like a real mirror. **(accepted default)**
2. The picture comes out of the notch: a black panel grows downward from the
   notch with the picture inside, and slides back into it when closed.
3. A setting chooses how the mirror is opened: by clicking the notch, or by
   a menu bar icon. It is a toggle between the two.
4. The camera runs only while the panel is open, so the green camera light
   goes out on close. **(accepted default)**
5. Nothing is saved or sent anywhere. **(accepted default)**

## Non-goals (later, not now)

- A keyboard shortcut to open the mirror
- Choosing another camera
- Resizing the panel
- Taking a snapshot

## Anti-goals

- The camera staying on after the panel is closed, in any situation
  (closing by click, by esc, quitting, the Mac going to sleep)
- The camera switching on without a deliberate click
- The app becoming unreachable: there must always be a way to change the
  setting and to quit, in both modes
- The invisible click area on the notch getting in the way of the menu bar
- Code a beginner can't follow

## How it behaves

**Opening and closing.** One click on the trigger (notch or icon) opens the
mirror; another click on it closes it. Clicking anywhere else, or pressing
`esc`, also closes it. **(accepted default)**

**The panel.**
- Black, attached to the top edge of the screen, centred on the notch. Its
  top corners are square (they sit against the screen edge); the bottom
  corners are rounded.
- Width: one third of the screen's width, never narrower than the notch.
  Fixed size. **(accepted default)**
- The picture is 16:9, with a small black margin left, right and below, and
  starts just under the notch so the notch never covers it. The picture has
  slightly rounded corners. **(Claude's call)**
- Animation **(Claude's call)**: the black shape starts at the size of the
  notch and grows to full size in about 0.3 seconds, revealing the picture
  like a curtain from the top; closing runs the same in reverse, a little
  faster. The picture itself does not scale.

**Which screen (Claude's call).** The panel always appears on the built-in
display with the notch, because that is where the camera is. If there is no
screen with a notch (lid closed with an external display, or the display is
set to scale below the camera), it drops from the top centre of the main
screen instead. **(accepted default for the no-notch case)**

**The two ways to open it.**
- *Notch* (default, **Claude's call**, because the user wants fewer icons):
  an invisible click area sits exactly on the notch. Left-click toggles the
  mirror. Right-click shows the menu. No menu bar icon is shown.
- *Menu bar icon*: an icon in the menu bar. Left-click toggles the mirror,
  right-click shows the menu. The notch does not react.
- If *Notch* is chosen but no screen has a notch, the menu bar icon is shown
  for as long as that is the case, so the app stays reachable.
  **(Claude's call)**

**The menu (Claude's call)**, identical in both modes:

```
Open from
  ✓ Notch
    Menu Bar Icon
  ───────────
  ✓ Start at Login
  ───────────
  Quit NotchMirror
```

**Reaching the app when nothing is visible (Claude's call).** Opening
NotchMirror again from Applications or Spotlight while it runs shows a small
settings window with the same choices: Open from (Notch / Menu Bar Icon),
Start at Login, whether camera access is granted (with a button to open the
privacy settings if not), and Quit.

**The setting survives restarts.** It is stored in the app's preferences.

**Camera.** The Mac's built-in camera only; an iPhone offered as a camera is
ignored. **(accepted default)**

**Camera permission.** macOS asks once, the first time the mirror is opened.
If access is denied, the panel still opens and shows, instead of the
picture: "NotchMirror has no access to the camera." with a button
"Open Privacy Settings". If no built-in camera is found: "No built-in
camera found."

**The very first open (Claude's call).** While macOS shows its camera
question, the panel stays open and shows "Waiting for camera access…".
Clicks elsewhere do not close it during that time, because answering the
question is itself a click elsewhere. Once access is granted the picture
appears in the same panel; if it is denied, the no-access text appears.

**The first launch (Claude's call).** In Notch mode a freshly installed app
shows nothing at all, so the first launch opens the settings window once,
with one extra line at the top: "Click the notch to open the mirror.
Right-click it for these settings." A stored flag makes sure this happens
only once.

**Other moments the mirror closes (Claude's call).** When the Mac goes to
sleep or the screen locks, and when displays are connected, removed or
rearranged (the click area then moves to the notch's new position).

**Start at login.** On by default **(accepted default)**. As in the sibling
apps **(Claude's call)**: the first time a copy installed in /Applications
runs, it adds itself to the login items without asking and remembers that it
did, in the app's preferences. Those survive reinstalling, so the app never
switches it back on after the user switched it off.

## Constraints

- macOS 27, Xcode 27.2, Apple silicon MacBook with a notch. Swift + AppKit;
  SwiftUI only for the small settings window. AVFoundation for the camera.
  No third-party libraries. Deployment target macOS 14.0.
- New local repo `notch-mirror`; no remotes, no pushing unless asked.
- Menu-bar-only app (no Dock icon), App Sandbox off, signed to run locally,
  bundle identifier `local.notchmirror`.
- Same project rules as the user's other apps (see `CLAUDE.md`): plain
  explanations after each step, simple code, feature branch then local
  merge, build and run before saying it is done.
- Project set up like the sibling projects: hand-written Xcode project with
  a hosted unit test target and a shared scheme, single-instance handling,
  `scripts/install.sh`.
- No personal names or paths in any file or commit. Commits use the
  no-reply Git identity already configured in the repo.
- Geometry and settings logic live in pure, tested code. Tests never switch
  the camera on.

## How it gets made

**Notch position.** macOS reports it per screen: `safeAreaInsets.top` is the
notch's height, and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` are the
menu bar areas left and right of it; the notch is the gap between them.
Checked on this Mac: screen 1710 × 1107 points, notch 185 × 33.5 points,
starting 762.5 points from the left.

**Windows.** Two borderless, non-activating panels above the menu bar
(window level: main menu + 3), present on every Space and over full-screen
apps:
- the mirror panel, transparent except for the black shape;
- the notch click area, a black window slightly smaller than the notch (so
  nothing peeks out past the notch's rounded corners). It must be black, not
  transparent: fully transparent windows let clicks fall through, and the
  notch hides it anyway.

**Animation.** The mirror view is always full size; a mask layer anchored at
the top centre grows from the notch's size to the full size.

**Camera.** `AVCaptureSession` with the built-in wide-angle camera, shown
with `AVCaptureVideoPreviewLayer`, aspect-fill, mirrored. Checked on this
Mac: the built-in camera reports as built-in wide-angle; the iPhone reports
as an external device flagged as Continuity Camera, and is excluded. The
session starts when the panel opens and stops when the closing animation
ends, and also when the app quits or the Mac goes to sleep.

**Suggested code layout** (builder may adjust): notch geometry (pure);
settings (pure decision logic plus storage); camera; mirror panel and view;
notch click area; app delegate tying them together; settings window; and the
single-instance and login-item files copied from the sibling projects.

## Known risks

- **Clicks on the notch.** Whether a window behind the notch reliably
  receives clicks on macOS 27 can only be confirmed by the user on the real
  machine. If it does not work, the menu bar icon mode still does, and the
  settings window lets the user switch.
- **Permission after reinstalling.** With local signing, macOS can treat a
  rebuilt app as new and ask for camera access again.
- **Looks.** Claude cannot see the notch or the picture. Alignment with the
  notch, the animation and the mirroring need the user's eyes.

## Left to the builder

- Exact margins, corner radii, animation timing, the menu bar icon symbol
- How esc and clicks elsewhere are detected
- Wording of small labels in the settings window

## Done means

- Tests pass; the app is installed and running.
- The user has opened the mirror from the notch and from the menu bar icon,
  seen themselves mirrored, and confirmed that the panel comes out of the
  notch and that the camera light goes off on close.
- The toggle works and survives a restart of the app.
- The feature branch is merged into `main` locally.
- The user has been told what was not verified.
