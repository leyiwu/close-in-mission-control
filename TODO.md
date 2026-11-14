# To do

## Next

- [ ] **Check the two-line Homebrew install on a clean setup** (tap removed and untrusted).
      Checked so far: `brew trust --tap` accepts a tap that is not tapped yet. Not checked:
      that `brew install --cask leyiwu/tap/...` then taps it by itself.
- [ ] **Understand how the logging works** (to study, not to change): how the app writes
      `~/Library/Logs/CloseInMissionControl/app.log`, what each kind of line records
      (Mission Control opening and closing, hovers, matches, clicks, close results), how
      the Debug menu's dump captures the Dock's Accessibility tree, and how those files
      were read during development to diagnose problems. Start with `Log.swift`,
      `Probe.swift` and the `Log.write` calls in `Controller.swift`.

## Adoption

- [ ] **Verify on an Intel Mac.** The Intel half of the universal build compiles but has
      never been run.

- [ ] **Fund notarization through donations.**
      1. Make a short video introducing the project: open source, free to download.
      2. Add a "Buy me a coffee" link (README and video description) with a stated goal
         of US$99, the yearly cost of the Apple Developer Program.
      3. When the goal is reached: enrol, sign with a Developer ID certificate, notarize,
         ship a release that opens without the first-launch block, and close the
         donation link.
      Open points: the fee recurs every year; the Developer ID certificate shows a
      legal name; existing users re-grant Accessibility once when the signature changes.

## Community

- [ ] **Reach out to the MissionClose author.** Open a friendly issue: built something
      similar independently, here is the strict-matching approach in case it is useful.
      Possible outcomes: contributing it upstream, swapping notes on macOS-update breakage
      (both projects depend on undocumented Dock behaviour), or just having a contact.
      Note for the message: this project was built without reading their code; only their
      README was read, after the prototype already worked.

## Bugs

- [ ] Other apps whose thumbnail label differs from the window title may still fail if the
      shape fallback is ambiguous. Collect cases from the log.

## Untested

- [ ] An external monitor.
- [ ] Stage Manager.
- [ ] Launch at Login after a real restart (the toggle registers and macOS confirms
      "Login Item Added"; an actual login has not been tried).

- [ ] **Check the Chinese README's macOS wording on a Chinese-language system** (the
      first-launch dialog, "仍要打开", "隐私与安全性"). Written from memory, with the English
      term in brackets as a hedge.
- [ ] **Traditional Chinese (zh-Hant).** A Mac set to it falls back to English today.

## Optional features

- [ ] App Exposé (⌃↓) support; its Accessibility group is named `appexpose`.
- [ ] Cheaper idle detection. The app polls the Dock 4 times a second; measured 0% CPU.
- [ ] Development-only tweak file for button colour and size, to tune the look without rebuilding.
- [ ] **Shortcut keys** for the hovered window, such as ⌘W to close or ⌘M to minimize.
      Low priority and possibly never: the pointer already has to be on the window to
      select it, at which point clicking the × is just as quick, and Mission Control has
      no keyboard way to pick a window. Minimize would also widen the close-only scope.

## Cleanup

- [ ] Decide whether the Debug menu's dump item stays in release builds. It is useful for
      diagnosing breakage after a macOS update.

## Later

- [ ] **Re-arrange after a close.** Mission Control leaves an empty slot where a closed
      window was; macOS does not re-lay out while it is open (verified on macOS 26.6: the
      Dock still lists the dead thumbnail). A workaround was prototyped and shelved:
      leave and re-enter Mission Control about 0.6 s after the last close. It was never
      tested on screen, and it trades away "leave Mission Control untouched".
      Related, but specific to QuickTime Player: it accepts the close yet keeps playing,
      audio included, until Mission Control is left. Chrome playing a YouTube video
      closes at once, so this is QuickTime deferring its own close, not a general lag.

## Done

- [x] Feasibility probe, detection, overlay button, click interception
- [x] Match windows whose thumbnail label differs from their title (Photos)
- [x] Button design: 21 pt silver disc, grey on hover, centred on the top-left corner
- [x] Launch at Login menu item
- [x] Stable local signing so the Accessibility grant survives rebuilds
- [x] MIT license, git repository, published on GitHub
- [x] Universal release zip and `scripts/release.sh` (v0.1.0; v0.1.1 adds the app icon)
- [x] README screenshot
- [x] Quit menu item shortened to "Quit"
- [x] Simplified Chinese: the menu and welcome window follow the Mac's language, and
      `README.zh-CN.md` mirrors the README
- [x] Released as v0.1.7, with the cask's `zap trash` covering the preferences file
- [x] Menu → Language (Follow System / English / 简体中文) switches the menu and welcome
      window live and remembers the choice; the only thing the app stores
- [x] The × fades in from 30% to full over 0.12 s (skipped when Reduce Motion is on)
- [x] Menu shows the version (development builds say so and show their commit) and links to
      the release notes; the log records it at every start
      Verified on the installed 0.1.6 release: "Version 0.1.6", no commit, grant kept, no
      "Open Anyway" on upgrade.
- [x] Opening the app by hand or reopening it shows the welcome window (verified on the
      released 0.1.5 from Applications); starting at login is meant to stay quiet, not yet seen
- [x] Welcome window with a live Accessibility status, replacing the plain alert; the live
      grant flow is verified (the window floats above System Settings and shows "Allowed")
- [x] README rewritten for everyday users, with an Uninstall section; developer material
      moved to `DEVELOPING.md`
- [x] Homebrew install shortened to two lines
- [x] QuickTime Player: answers normally with a movie open; only its "Open" file picker gets no × (correct)
- [x] Homebrew upgrade 0.1.2 → 0.1.3 verified: no first-launch block, Accessibility grant carried over
- [x] Unsaved-changes windows: the save prompt appears and the app switches to that window (tested with TextEdit)
- [x] Identical windows in one app each get a ×, paired by front-to-back order (tested with Finder)
- [x] Disk image with an Applications shortcut (`scripts/make-dmg.sh`); the zip stays for Homebrew
- [x] Install verified end to end on macOS 26.6: browser download with the first-launch
      bypass, and `brew install --cask`
- [x] "Similar projects" section in the README
- [x] App icon (`scripts/make-icon.sh` regenerates it)
- [x] Homebrew tap: `leyiwu/homebrew-tap` (update its cask version and sha256 on each release)
