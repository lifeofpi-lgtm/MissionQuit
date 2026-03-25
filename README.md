# MissionQuit

Quit apps directly from Mission Control on macOS. Hover over a window thumbnail and press **⌘Q** to quit that app.

## How it works

1. Installs a global event tap that listens for ⌘Q
2. Detects if Mission Control is active (via Dock window inspection)
3. Uses the Accessibility API to identify the app under your cursor
4. Terminates that app — ⌘Q works normally outside Mission Control

## Requirements

- macOS 13+
- **Accessibility permission** must be granted in System Settings → Privacy & Security → Accessibility

## Build & Run

```bash
swift build
open MissionQuit.app
# or run directly:
.build/debug/MissionQuit
```

To create the app bundle:

```bash
bash build.sh
```

## Menu bar

MissionQuit runs as a menu bar app (⌘Q icon). From the menu you can:
- Toggle **Launch at Login**
- Quit MissionQuit
