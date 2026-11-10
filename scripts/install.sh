#!/bin/bash
# Builds NotchMirror and installs it into /Applications, replacing an older copy.
# Run from the project folder:  ./scripts/install.sh
set -e
cd "$(dirname "$0")/.."

echo "Building…"
xcodebuild -project NotchMirror.xcodeproj -scheme NotchMirror -configuration Release \
    -derivedDataPath build build > build-install.log 2>&1 || {
    echo "The build failed. See build-install.log."; exit 1; }
rm -f build-install.log

# Stop a running copy, then replace the installed app.
pkill -x NotchMirror || true
sleep 1
rm -rf /Applications/NotchMirror.app
cp -R build/Build/Products/Release/NotchMirror.app /Applications/NotchMirror.app

# Remove the built copies from the project folder. Otherwise Spotlight
# offers several apps called NotchMirror, and it is easy to start the wrong one.
rm -rf build/Build/Products/Release/NotchMirror.app build/Build/Products/Debug/NotchMirror.app

open /Applications/NotchMirror.app
echo "Installed and started /Applications/NotchMirror.app"
echo "macOS treats a new build as a new app, so it may ask for camera"
echo "access again the next time you open the mirror. If the mirror says it"
echo "has no access instead of asking, run:"
echo "  tccutil reset Camera local.notchmirror"
echo "and open the mirror again."
