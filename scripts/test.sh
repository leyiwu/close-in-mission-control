#!/bin/sh
# Runs the unit tests. With full Xcode, plain `swift test` works.
# With only the Command Line Tools, Swift Testing must be located by hand.
set -eu
cd "$(dirname "$0")/.."
DEV="$(xcode-select -p)"
case "$DEV" in
*CommandLineTools*)
    FW="$DEV/Library/Developer/Frameworks"
    LIB="$DEV/Library/Developer/usr/lib"
    exec swift test -Xswiftc -F -Xswiftc "$FW" -Xlinker -F -Xlinker "$FW" \
        -Xlinker -rpath -Xlinker "$FW" -Xlinker -rpath -Xlinker "$LIB" "$@"
    ;;
*) exec swift test "$@" ;;
esac
