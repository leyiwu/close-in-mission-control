#!/bin/sh
# Builds "build/Close in Mission Control.app" from the Swift package and signs it.
set -eu
cd "$(dirname "$0")/.."
swift build -c release
APP="build/Close in Mission Control.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CloseInMissionControl "$APP/Contents/MacOS/CloseInMissionControl"
cp Support/Info.plist "$APP/Contents/Info.plist"
# Prefer the stable local identity (see scripts/make-signing-identity.sh); else ad-hoc.
IDENTITY="CloseInMissionControl Local Signing"
if security find-identity -p codesigning | grep -q "$IDENTITY"; then
    codesign --force --sign "$IDENTITY" --options runtime "$APP"
else
    codesign --force --sign - --options runtime "$APP"
fi
echo "Built $APP"
