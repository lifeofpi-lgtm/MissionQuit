# Handoff

## Last Session Summary (2026-08-26)
Reworked the core of MissionQuit after empirical probing showed the original logic was wrong in two places:
- Mission Control detection fired constantly (the Dock's own window is always at layer 20), so ⌘Q was being intercepted everywhere and quit whatever app was under the cursor, not the frontmost app.
- App identification used fuzzy substring matching of AX titles against app names, which could match on-screen text (e.g. the word "mail" in a terminal).

Both replaced. New build installed to /Applications and running with Accessibility intact; verified via AX that the menu reports "Active".

## Files Modified
- Sources/MissionQuit/MissionControlQuit.swift: new detector, pid-based hit-test, modifier and autorepeat handling, AX timeout, swallow-on-miss inside Mission Control
- Sources/MissionQuit/AppDelegate.swift: live menu (NSMenuDelegate), permission status + "Open Accessibility Settings", polls until trusted then starts tap, ✓ flash after a quit, working About item
- build.sh, README.md: release builds, updated docs

## Decisions Made
See decisions.md (2026-08-26 entries).

## In Progress
Nothing.

## Next Steps
- Real-world use for a few days. Things to watch: ⌘Q on a Space label or empty Mission Control background should do nothing; multi-monitor hover should resolve the right app.
- Detection relies on the Dock adding full-screen windows during Mission Control, observed on macOS 26 (Darwin 25.5). Re-probe with scratch script if a macOS update breaks it.
- Only one probe sample of Exposé / ⌘Tab switcher behaviour; ⌘Tab was not tested (switcher window is not full-screen so should not trigger).
