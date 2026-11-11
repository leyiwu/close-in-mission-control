#!/bin/sh
# Builds a universal app and packs it for a GitHub release: a .dmg for people
# (drag to Applications) and a .zip for the Homebrew cask.
# The version comes from CFBundleShortVersionString in Support/Info.plist.
set -eu
cd "$(dirname "$0")/.."
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
./scripts/test.sh >/dev/null
UNIVERSAL=1 ./scripts/build-app.sh
ZIP="build/Close-in-Mission-Control-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "build/Close in Mission Control.app" "$ZIP"
echo "Created $ZIP"
shasum -a 256 "$ZIP"
./scripts/make-dmg.sh "$VERSION"
