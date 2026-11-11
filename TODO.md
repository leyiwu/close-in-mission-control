# To do

## Adoption

- [ ] **Verify the install steps** on a freshly downloaded copy of the release (the
      first-launch bypass has only been checked against how macOS documents it), and on
      an Intel Mac.
- [ ] **Try a real Homebrew install** (`brew install --cask`); the cask passes Homebrew's
      style check and its download verifies, but it has not been installed end to end.
- [ ] **Screenshot or short recording** of the × in Mission Control at the top of the README.
- [ ] **Next release (v0.1.1)** so the download includes the app icon; v0.1.0 has none.

## Community

- [ ] **Reach out to the MissionClose author.** Open a friendly issue: built something
      similar independently, here is the strict-matching approach in case it is useful.
      Possible outcomes: contributing it upstream, swapping notes on macOS-update breakage
      (both projects depend on undocumented Dock behaviour), or just having a contact.
      Note for the message: this project was built without reading their code; only their
      README was read, after the prototype already worked.

## Bugs

- [ ] **QuickTime Player never answers** window-list requests (AX error -25204), so its
      windows would get no ×.
- [ ] Other apps whose thumbnail label differs from the window title may still fail if the
      shape fallback is ambiguous. Collect cases from the log.

## Untested

- [ ] Two windows with the same title and shape (should get no ×).
- [ ] A window with unsaved changes (should show its save prompt).
- [ ] An external monitor.
- [ ] Stage Manager.
- [ ] The Launch at Login toggle.

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

## Done

- [x] Feasibility probe, detection, overlay button, click interception
- [x] Match windows whose thumbnail label differs from their title (Photos)
- [x] Button design: 21 pt silver disc, grey on hover, centred on the top-left corner
- [x] Launch at Login menu item
- [x] Stable local signing so the Accessibility grant survives rebuilds
- [x] MIT license, git repository, published on GitHub
- [x] Universal release zip and `scripts/release.sh` (v0.1.0)
- [x] "Similar projects" section in the README
- [x] App icon (`scripts/make-icon.sh` regenerates it)
- [x] Homebrew tap: `leyiwu/homebrew-tap` (update its cask version and sha256 on each release)
