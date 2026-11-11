#!/bin/sh
# Packs the already-built app into a disk image with an Applications shortcut,
# so installing is the familiar drag-to-Applications. Usage: make-dmg.sh <version>
set -eu
cd "$(dirname "$0")/.."
VERSION="$1"
APP="build/Close in Mission Control.app"
DMG="build/Close-in-Mission-Control-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Close in Mission Control.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Close in Mission Control" -srcfolder "$STAGE" -format UDZO "$DMG"
echo "Created $DMG"
shasum -a 256 "$DMG"
