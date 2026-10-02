# Decisions Log

_Architectural and design decisions for this project. Updated by Claude Code during sessions._

## Format
- **Date** | **Decision** | **Rationale** | **Alternatives Considered**

- **2026-08-26** | Detect Mission Control by Dock-owned, non-"Dock"-named windows whose bounds equal a screen frame | Probing showed the Dock's main window is permanently at layer 20, so the old `layer >= 20` check was always true. In Mission Control the Dock adds two full-screen windows (layers 18 and 20). Matching on bounds rather than layer avoids depending on an undocumented layer number | Layer-18 check alone; AX inspection of the Dock process (heavier, runs inside the event tap)
- **2026-08-26** | Identify the hovered app by the pid of the AX element under the cursor | In Mission Control the system-wide AX hit-test resolves to the real app behind the thumbnail, so pid is exact. Name matching against window text was a false-positive risk | Keep title matching as fallback (rejected: no observed case where pid fails but title works)
- **2026-08-26** | Inside Mission Control, swallow ⌘Q when no quittable app is under the cursor | Passing it through would quit the frontmost app, which the user did not intend | Pass through (original behaviour)
- **2026-08-26** | Only intercept when Command is the sole modifier (ignoring caps lock / fn) | ⌘⌥Q, ⌘⇧Q etc. are bound by other apps and should not be hijacked | Any event with the Command flag (original)
- **2026-08-26** | Ship release builds from build.sh | No reason to install a debug binary | Debug (original)
- **2026-10-01** | Add an MIT license (holder "Pasha I.") | Without a license nobody may legally reuse the public code; matches the MDmaster repo | GPL (not chosen, no reason to force derivatives open)
- **2026-10-01** | Leave the Gmail author email in the six existing public commits | Irshad chose not to rewrite; a fresh repo would break the already-public URL. New commits use the GitHub noreply address | History rewrite or fresh repo
- **2026-10-02** | Re-author the unpushed local commits with the noreply address during the rebase | They were not public yet, so rewriting them costs nothing and avoids adding more Gmail-authored commits | Keep the Gmail author on them
- **2026-10-02** | Keep CLAUDE.md, handoff.md and decisions.md tracked (public) after a content review | Existing setup for this repo, reviewed clean of emails, paths and secrets | Untrack and gitignore them as done for the MD editor project
