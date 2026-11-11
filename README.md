<img src="Support/icon.png" width="96" alt="App icon">

# Close in Mission Control

A tiny macOS menu-bar utility that adds one thing to Mission Control: a close button on
the window thumbnail you are hovering.

<img src="Support/screenshot.png" width="620" alt="A window thumbnail in Mission Control with a close button on its top-left corner">

Coming from Windows, where Task View has an × on every window, Mission Control has no way
to close a window without leaving it. This adds that × and nothing else.

- Close only. No minimize, no full screen, no keyboard shortcuts.
- No network access, no analytics, no auto-update.
- One setting: Launch at Login (off by default).
- Mission Control itself is untouched; every other click behaves as it always has.

Swift + AppKit, public APIs only. Verified on macOS 26.6 with a single display.

## How it works

1. Mission Control is drawn by the Dock. While it is open, the Dock's Accessibility tree
   lists each window thumbnail with a title and frame.
2. Once the thumbnails stop moving, the hovered one is matched to a real window by title
   and aspect ratio. If that match is not unique, no button is shown: closing the wrong
   window is worse than showing nothing.
3. A small × is drawn in the thumbnail's corner. Mission Control does not deliver clicks
   to other apps' windows, so an event tap (active only while Mission Control is open)
   catches a left click that begins on the ×.
4. The click presses the window's own close button through Accessibility, so unsaved
   documents still show their normal save prompt.

All of this rests on undocumented macOS behaviour, listed in [DEPENDENCIES.md](DEPENDENCIES.md).
Expect macOS updates to break it from time to time.

## Install

With Homebrew:

    brew tap leyiwu/tap
    brew trust leyiwu/tap
    brew install --cask close-in-mission-control

(`brew trust` is needed on recent Homebrew versions, which refuse third-party taps until
you trust them; skip it if your Homebrew does not have the command.) Then continue from
step 3 below.

Or by hand:

1. Download `Close-in-Mission-Control-<version>.zip` from the
   [latest release](https://github.com/leyiwu/close-in-mission-control/releases/latest).
2. Unzip it and move **Close in Mission Control** to your Applications folder.
3. Open it. macOS will refuse the first time with a dialog titled **"Close in Mission
   Control" Not Opened** ("Apple could not verify…"), because the app is not notarized by
   Apple (that needs a paid developer account). Click **Done**, not Move to Trash. Then
   open System Settings → Privacy & Security, scroll down, and click **Open Anyway**.
   Or, in Terminal:

       xattr -dr com.apple.quarantine "/Applications/Close in Mission Control.app"

4. Grant Accessibility access when asked (see [Permission](#permission)).

The app runs on Apple silicon and Intel Macs with macOS 14 or later. Releases are signed
with the same self-signed certificate each time, so the Accessibility grant should carry
over when you replace the app with a newer version.

## Build from source

Requires macOS 14+ and the Swift 6 toolchain (Xcode or the Command Line Tools).

    ./scripts/build-app.sh
    open "build/Close in Mission Control.app"

Tests: `./scripts/test.sh`. Release zip: `./scripts/release.sh`.

## Permission

The app needs Accessibility access (System Settings → Privacy & Security → Accessibility)
to read thumbnail positions, catch the click on the ×, and press a window's close button.
It explains this before macOS asks.

By default builds are ad-hoc signed, so macOS treats every rebuild as a new app and the
grant must be given again. Run `./scripts/make-signing-identity.sh` once to create a
self-signed identity in your login keychain; builds signed with it keep the grant.

## Known limitations

- Windows that share both a title and a shape get no button.
- Only windows on the current Space are reachable.
- A window whose own red close button is disabled gets no button. Apps disable it while
  something blocks closing, such as a sign-in prompt or a sheet.
- App Exposé (⌃↓) is not supported.
- Multiple displays and Stage Manager are untested.
- Diagnostics are written to `~/Library/Logs/CloseInMissionControl/app.log` (window titles
  and app names; the file never leaves your Mac).

## Layout

- `Sources/CloseInMissionControlCore` — pure logic (scanner, settle detection, matcher)
  and the thin live Accessibility wrapper
- `Sources/CloseInMissionControl` — menu-bar shell, permission flow, overlay, event tap
- `Tests` — unit tests for the pure logic

## Similar projects

This one does a single thing. If you want more, these are good choices:

- [MissionClose](https://github.com/beqaabu/MissionClose) — free and open source. Adds
  close, minimize and full-screen buttons, keyboard shortcuts, quitting apps, App Exposé
  support and settings.
- [Mission Control Plus](https://fadel.io/missioncontrolplus) — a paid app with a free
  trial. Adds a close button plus ⌘W, ⌘M and ⌘Q shortcuts.

Want shortcuts, minimize or quit? Use one of those. Want only a close button that never
guesses which window you meant? This one.

## License

MIT. See [LICENSE](LICENSE).
