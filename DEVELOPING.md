# Developing

Notes for people who want to build, change or release Close in Mission Control. Everyday
users do not need any of this; see the [README](README.md).

## How it works

1. Mission Control is drawn by the Dock. While it is open, the Dock's Accessibility tree
   lists each window thumbnail with a title and frame.
2. Once the thumbnails stop moving, the hovered one is matched to a real window by title
   and aspect ratio, and by front-to-back order when one app has several look-alikes. If
   the match is still not unique, no button is shown: closing the wrong window is worse
   than showing nothing.
3. A small × is drawn in the thumbnail's corner. Mission Control does not deliver clicks
   to other apps' windows, so an event tap (active only while Mission Control is open)
   catches a left click that begins on the ×.
4. The click presses the window's own close button through Accessibility, so unsaved
   documents still show their normal save prompt. When that happens, the app switches to
   the window (as a click on its thumbnail would) so the prompt appears on it.

All of this rests on undocumented macOS behaviour, listed in
[DEPENDENCIES.md](DEPENDENCIES.md). Expect macOS updates to break it from time to time.
Only public APIs are used.

## Layout

- `Sources/CloseInMissionControlCore` — pure logic (scanner, settle detection, matcher)
  and the thin live Accessibility wrapper
- `Sources/CloseInMissionControl` — menu-bar shell, welcome window, permission watcher,
  overlay, event tap
- `Tests` — unit tests for the pure logic
- `scripts` — build, test, release, icon and signing helpers

## Build and test

Requires macOS 14+ and the Swift 6 toolchain (Xcode or the Command Line Tools).

    ./scripts/build-app.sh
    open "build/Close in Mission Control.app"

Tests: `./scripts/test.sh` (works with Command Line Tools only; plain `swift test` needs
full Xcode). Launch with `--welcome` to force the welcome window. It also shows whenever the app is
opened by hand or reopened while running, but not when macOS starts it at login.

## Signing and the Accessibility grant

By default builds are ad-hoc signed, so macOS treats every rebuild as a new app and the
Accessibility grant must be given again. Run `./scripts/make-signing-identity.sh` once to
create a self-signed identity in your login keychain; builds signed with it keep the grant,
and so do releases signed with the same identity. Releases are not notarized by Apple.

## Releasing

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`.
2. `./scripts/release.sh` runs the tests and builds a universal app, then writes
   `build/Close-in-Mission-Control-<version>.dmg` (for people) and `.zip` (for Homebrew).
3. Push, then create a GitHub release with both files and their SHA-256 checksums.
4. In the `leyiwu/homebrew-tap` repository, update `version` and `sha256` in
   `Casks/close-in-mission-control.rb` to the zip's.

## Diagnostics

The app appends to `~/Library/Logs/CloseInMissionControl/app.log`: Mission Control opening
and closing, hovers, matches, clicks and close results. **Debug → Dump Mission Control AX
Tree in 5 s** writes the Dock's Accessibility tree to the same folder.
