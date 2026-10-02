# Handoff

## 2026-10-02 Session close-out: history reconciled and pushed

### Changes made
- Fetched origin, found main ahead 2 and behind 1, and ran `git rebase origin/main` with an `--exec` step that
  re-authored every local commit with the GitHub noreply address. The Mission Control fix (now db6b254) and the
  handoff commits sit on top of the license commit a081e3b.
- Replaced a personal email address in this file's earlier entry with "the Gmail address" before it went public.
- Pushed to origin/main (a081e3b..8ed2f54, then a follow-up docs commit recording the push). Local main is level
  with origin/main.

### Verified
- Before the rebase: grepped CLAUDE.md, handoff.md, decisions.md, README.md, Sources, build.sh and Info.plist for
  emails, /Users paths and secret-like strings; the only hit was the bundle ID com.pirshad.MissionQuit.
- After the push: the GitHub commits API listed the new commits, all with the noreply email.

### Not verified
- The app was not rebuilt or launched from the rebased tree, and the Mission Control fix has not been re-tested
  since it was published.

### Deferred
- CLAUDE.md, handoff.md and decisions.md are tracked and therefore public. Keep them free of personal emails and
  local paths, or gitignore and untrack them.
- The six oldest public commits still show the Gmail author address (Irshad chose not to rewrite).

## 2026-10-01 Session: license added on GitHub (done from a scratchpad clone, not this folder)

### Changes made
- Added `LICENSE` (MIT, holder "Pasha I.", 2026) and pushed it to `origin/main` as commit a081e3b, authored with the
  GitHub noreply address. Nothing in this folder was edited for that.

### Verified
- GitHub API reports the license as MIT. A scan of the public clone found no secrets or local paths; the only
  hit was the bundle ID com.pirshad.MissionQuit. The six earlier public commits show the Gmail address;
  Irshad chose to leave that.

### Not verified
- The rebased build was not recompiled or launched after the rebase (only history changed, no code).

### Deferred
- Rebase done 2026-10-01: `git rebase origin/main` put the Mission Control fix and the handoff commits on top of
  the license commit a081e3b, and the three local commits were re-authored with the noreply address. Reviewed
  before rebasing: no emails, local paths or secrets in the code, README, CLAUDE.md, handoff.md or decisions.md.
- Pushed 2026-10-01 (a081e3b..8ed2f54). The public repo now has the Mission Control fix. CLAUDE.md, handoff.md
  and decisions.md are public because they are tracked, so keep handoff.md free of personal emails and local
  paths, or gitignore and untrack them.

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
