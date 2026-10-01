# Handoff

## 2026-10-01 Session: license added on GitHub (done from a scratchpad clone, not this folder)

### Changes made
- Added `LICENSE` (MIT, holder "Pasha I.", 2026) and pushed it to `origin/main` as commit a081e3b, authored with the
  GitHub noreply address. Nothing in this folder was edited for that.

### Verified
- GitHub API reports the license as MIT. A scan of the public clone found no secrets or local paths; the only
  hit was the bundle ID com.pirshad.MissionQuit. The six earlier public commits show the Gmail address;
  Irshad chose to leave that.

### Not verified
- This folder was not fetched after the push. `git status` earlier showed `main` ahead of `origin/main` by 2.

### Deferred
- URGENT-ish: this folder holds 2 commits that are NOT on GitHub (fca7a3d "Fix Mission Control detection and app
  identification; permission UX" and 8508e40 "docs: session handoff"). The public repo therefore still has the
  OLD, buggy detection code, and now diverges from this folder because of a081e3b. Run `git pull --rebase`, then push.
- Before pushing: those two commits track CLAUDE.md, handoff.md and decisions.md, which would become public. Review
  them for local paths, or gitignore and untrack them as was done for the MD editor project, then push.
- No commit was made for this entry because of the divergence above; commit it after the rebase.

## Last Session Summary (2026-08-26)
Reworked the core of MissionQuit after empirical probing showed the original logic was wrong in two places:
- Mission Control detection fired constantly (the Dock's own window is always at layer 20), so ⌘Q was being intercepted everywhere and quit whatever app was under the cursor, not the frontmost app.
- App identification used fuzzy substring matching of AX titles against app names, which could match on-screen text (e.g. the word "mail" in a terminal).

Both replaced. New build installed to /Applications and running with Accessibility intact; verified via AX that the menu reports "Active". User tried it and confirmed it is "much better now".

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
