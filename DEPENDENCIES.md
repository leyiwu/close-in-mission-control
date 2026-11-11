# Undocumented macOS dependencies

Only public APIs are called. The behaviours below are not documented by Apple and can change
in any release. The rule on failure is always: show no button rather than guess.

| # | Assumption | Used by | Verified on | If it breaks |
|---|------------|---------|-------------|--------------|
| 1 | Mission Control is drawn by the process with bundle id `com.apple.dock` | probe, detector | macOS 26.6 | nothing is detected; app stays idle |
| 2 | While Mission Control is open, the Dock's AX tree contains an element with `AXIdentifier == "mc"` | probe, detector | macOS 26.6 | same as 1 |
| 3 | Window thumbnails are `AXButton` children of the group with `AXIdentifier == "mc.windows"`, each with a title and frame but no app name or window id | scanner, matcher | macOS 26.6 | no thumbnails found; no button shown |
| 4 | A panel at `CGShieldingWindowLevel()` with `.stationary` is drawn above Mission Control | overlay | macOS 26.6 | button invisible; clicks in its area would still close a window, so this must be re-verified per release |
| 5 | Mission Control does **not** deliver clicks to other apps' windows (verified: the click selected the thumbnail instead). A `CGEventTap` placed at the head of the HID/session tap chain sees the click first and can swallow it | click interceptor | macOS 26.6 | click falls through to Mission Control (window is selected, not closed) |

## Known limitations

- Thumbnails carry only a title, so a window is matched by title plus aspect ratio. Two
  windows with the same title and shape get no button.
- Mission Control is detected by polling the Dock (4 times a second while idle, 20 while open).

- Ad-hoc signing: the Accessibility grant does not survive a rebuild.
- The app cannot be sandboxed; sandboxed apps cannot use Accessibility on other apps.

## Private APIs considered and not used

- `_AXUIElementGetWindow` (maps an AX window to a CGWindowID) — would only help with
  windows that share a title; we match on app, title and aspect ratio instead.
