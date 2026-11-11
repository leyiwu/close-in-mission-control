#!/bin/sh
# Regenerates Support/AppIcon.icns and Support/icon.png from scripts/make-icon.swift.
set -eu
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swift scripts/make-icon.swift "$TMP/icon.png"
SET="$TMP/AppIcon.iconset"
mkdir "$SET"
for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$TMP/icon.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" "$TMP/icon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Support/AppIcon.icns
sips -Z 256 "$TMP/icon.png" --out Support/icon.png >/dev/null
echo "Wrote Support/AppIcon.icns"
