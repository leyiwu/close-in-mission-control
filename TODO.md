# To do

## Adoption

- [ ] **Verify the install steps** on a freshly downloaded copy of the release (the
      first-launch bypass has only been checked against how macOS documents it), and on
      an Intel Mac.
- [ ] **Homebrew tap** with a cask that installs the release zip.
- [ ] **Screenshot or short recording** of the × in Mission Control at the top of the README.
- [ ] **App icon.** The app shows a blank icon in the Accessibility list.

## README

- [ ] **"Similar projects" section** replacing the current "Related" note. Link both and say
      what each is for, along the lines of: "Want shortcuts, minimize, quit? Use MissionClose
      or Mission Control Plus. Want only a close button that never guesses? This one."

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

## Done

- [x] Feasibility probe, detection, overlay button, click interception
- [x] Match windows whose thumbnail label differs from their title (Photos)
- [x] Button design: 21 pt silver disc, grey on hover, centred on the top-left corner
- [x] Launch at Login menu item
- [x] Stable local signing so the Accessibility grant survives rebuilds
- [x] MIT license, git repository, published on GitHub
- [x] Universal release zip and `scripts/release.sh` (v0.1.0)
