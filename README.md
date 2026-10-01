# MissionQuit

Quit apps directly from Mission Control on macOS. Hover over a window thumbnail and press **⌘Q** to quit that app.

## How it works

1. Installs a global event tap that listens for ⌘Q (Command as the only modifier)
2. Detects Mission Control by looking for the full-screen windows the Dock adds while it is showing
3. Hit-tests the cursor with the Accessibility API; in Mission Control this resolves to the real app behind the thumbnail
4. Asks that app to quit. Outside Mission Control ⌘Q passes through untouched. Inside it, if nothing quittable is under the cursor, ⌘Q is swallowed so it can't reach the frontmost app

## Requirements

- macOS 13+
- **Accessibility permission** must be granted in System Settings → Privacy & Security → Accessibility

## Build & Run

```bash
swift build -c release
open MissionQuit.app
# or run directly:
.build/release/MissionQuit
```

To create the app bundle:

```bash
bash build.sh
```

## Menu bar

MissionQuit runs as a menu bar app (⌘Q icon). From the menu you can:
- See whether the tap is active, or open Accessibility settings if permission is missing
- Toggle **Launch at Login**
- Quit MissionQuit

The icon briefly shows ✓ after a quit from Mission Control.
