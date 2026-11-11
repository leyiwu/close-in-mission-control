#!/bin/sh
# Builds a universal app and zips it for a GitHub release.
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
