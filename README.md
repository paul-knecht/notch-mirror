# NotchMirror

A small macOS app that works like a pocket mirror. One click, and a black
panel grows out of the notch with the live picture from the Mac's camera,
flipped left to right like a real mirror. Another click, `esc`, or a click
anywhere else, and it slides back into the notch.

## Why I built it

I wanted a quick look in the mirror before a call or a class, in one click. It comes out of the notch, so it feels like part of the Mac and adds no icon to the menu bar.

Built with [Claude Code](https://claude.com/claude-code) while learning Swift, Xcode and Git.

## Two ways to open it

- **Notch** (the default): click the notch. There is no menu bar icon.
- **Menu Bar Icon**: click the icon in the menu bar. The notch does not react.

Right-click the notch or the icon to switch between the two, to turn
"Start at Login" on or off, and to quit.

If nothing of the app is visible, open NotchMirror again from Applications
or Spotlight: a small settings window appears with the same choices.

On a Mac or display without a notch, the panel drops from the top centre of
the screen, and the menu bar icon is shown so the app stays reachable.

## Privacy

- The camera runs only while the mirror is open. When it closes, the green
  light next to the camera goes out.
- Nothing is recorded, saved or sent anywhere. The app has no network code.
- Only the Mac's built-in camera is used. An iPhone offered as a camera is
  ignored.

## Install

```bash
./scripts/install.sh
```

This builds the app, copies it to `/Applications` and starts it. The first
time you open the mirror, macOS asks whether NotchMirror may use the
camera. The app adds itself to the login items, so it starts with the Mac.

Because the app is signed for local use only, macOS can treat a rebuilt
copy as a new app and ask for camera access again.

## Build and test

Open `NotchMirror.xcodeproj` in Xcode and press Run, or:

```bash
xcodebuild -project NotchMirror.xcodeproj -scheme NotchMirror -derivedDataPath build test
```

The tests never switch the camera on.

Requires macOS 14 or later. Written in Swift with AppKit and AVFoundation.

## Good to know

- While the mirror is open it has the keyboard, so that `esc` can close
  it. Typing goes nowhere until you close the mirror.
- Clicking the notch only works on the MacBook's own display, since that
  is where the notch is.

## Not in this version

A keyboard shortcut, choosing another camera, resizing the panel, and
taking snapshots.

## Licence

MIT, see [LICENSE](LICENSE).
