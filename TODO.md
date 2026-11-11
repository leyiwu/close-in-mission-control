# To do

## Adoption

- [ ] **Verify on an Intel Mac.** The Intel half of the universal build compiles but has
      never been run.

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

## Optional features

- [ ] App Exposé (⌃↓) support; its Accessibility group is named `appexpose`.
- [ ] Cheaper idle detection. The app polls the Dock 4 times a second; measured 0% CPU.
- [ ] Development-only tweak file for button colour and size, to tune the look without rebuilding.

## Cleanup

- [ ] Decide whether the Debug menu's dump item stays in release builds. It is useful for
      diagnosing breakage after a macOS update.

## Later

- [ ] **Re-arrange after a close.** Mission Control leaves an empty slot where a closed
      window was; macOS does not re-lay out while it is open (verified on macOS 26.6: the
      Dock still lists the dead thumbnail). A workaround was prototyped and shelved:
      leave and re-enter Mission Control about 0.6 s after the last close. It was never
      tested on screen, and it trades away "leave Mission Control untouched".
      Related: a QuickTime Player window kept playing in its thumbnail after its × was
      clicked, and only went away on leaving Mission Control. Same root cause: Mission
      Control does not refresh while it is open, so what it shows can lag behind reality.

## Done

- [x] Feasibility probe, detection, overlay button, click interception
- [x] Match windows whose thumbnail label differs from their title (Photos)
- [x] Button design: 21 pt silver disc, grey on hover, centred on the top-left corner
- [x] Launch at Login menu item
- [x] Stable local signing so the Accessibility grant survives rebuilds
- [x] MIT license, git repository, published on GitHub
- [x] Universal release zip and `scripts/release.sh` (v0.1.0; v0.1.1 adds the app icon)
- [x] README screenshot
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
