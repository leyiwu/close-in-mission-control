#!/bin/sh
# Builds "build/Close in Mission Control.app" from the Swift package and signs it.
# Set UNIVERSAL=1 for a universal (arm64 + x86_64) binary.
set -eu
cd "$(dirname "$0")/.."
APP="build/Close in Mission Control.app"
BIN=CloseInMissionControl
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
if [ "${UNIVERSAL:-0}" = 1 ]; then
    # Apple silicon + Intel in one binary (used for releases).
    swift build -c release --triple arm64-apple-macosx14.0
    swift build -c release --triple x86_64-apple-macosx14.0
    lipo -create -output "$APP/Contents/MacOS/$BIN" \
        ".build/arm64-apple-macosx/release/$BIN" ".build/x86_64-apple-macosx/release/$BIN"
else
    swift build -c release
    cp ".build/release/$BIN" "$APP/Contents/MacOS/$BIN"
fi
cp Support/Info.plist "$APP/Contents/Info.plist"
# Prefer the stable local identity (see scripts/make-signing-identity.sh); else ad-hoc.
IDENTITY="CloseInMissionControl Local Signing"
if security find-identity -p codesigning | grep -q "$IDENTITY"; then
    codesign --force --sign "$IDENTITY" --options runtime "$APP"
else
    codesign --force --sign - --options runtime "$APP"
fi
echo "Built $APP"
