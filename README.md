# DDEV Manager

A lightweight macOS menu bar app for managing [DDEV](https://ddev.com) projects — start, stop, restart,
open in the browser, open the project folder, and power everything off — without touching a terminal.

![menu bar icon: a rounded-square "D" monogram badge](App/Assets.xcassets/MenuBarIcon.imageset/menubar@3x.png)

No Dock icon, no daemon: it's a thin SwiftUI panel that shells out to the real `ddev` CLI you already
have installed.

## Features

- **Project list**, sorted with running projects first, then starting/paused/stopped, alphabetically
  within each group.
- **Search field** to filter the list by name.
- **Per-project actions**: Start, Stop, Restart, open primary URL in the browser, open the project
  folder in Finder (always visible, uses the real absolute path `ddev` reports), open in your terminal,
  open Mailpit, copy URL (context menu / right-click for the last few).
- **Paused projects** can be resumed (Start) or fully stopped (Stop).
- **Engine status badge** showing whether the container backend is reachable, with version — works
  with Docker Desktop, OrbStack, Rancher Desktop, or Colima, detected automatically via the active
  `docker context`. If it's down, a **Start …** button appears, naming and launching whichever
  backend is actually in use (`colima start`, or opening the Docker Desktop / OrbStack / Rancher
  Desktop app).
- **Power off all** — runs `ddev poweroff`.
- **Action log** — a popover with the last 50 actions (success/failure with the real error text),
  persisted across restarts, since `ddev start` failures can be verbose and easy to miss.
- **Settings**: override the `ddev` executable path, tune the auto-refresh interval, launch at login.
- Auto-refreshes every 15s (configurable) while the panel is open, and after every action.

## Requirements

- macOS 14+ (Sonoma or later)
- [ddev](https://ddev.com) ≥ 1.25 installed (Homebrew: `brew install ddev/ddev/ddev`)
- A container engine ddev can use — **Docker Desktop, OrbStack, Rancher Desktop, and Colima are all
  supported**; the app detects whichever one is active via `docker context show` and offers the
  matching "Start …" action when it's down. Anything else `ddev` itself supports should work too, as
  long as `docker version` succeeds.
- Xcode command line tools + [XcodeGen](https://github.com/yonaskolb/XcodeGen) to build from source
  (`brew install xcodegen`)

## Build

```bash
./scripts/build.sh
```

This generates the Xcode project, runs the `DDEVKit` unit tests, builds a Release binary, and ad-hoc
signs it. Output: `dist/DDEVManager.app`.

The app is **ad-hoc signed, not notarized** — fine for building and running it yourself, not for
distributing to other machines without adjustment.

## Install

```bash
cp -R dist/DDEVManager.app /Applications/
open -a /Applications/DDEVManager.app
```

A small rounded-square "D" badge appears in the menu bar. Click it to open the panel. There's no Dock
icon — this is a pure menu-bar (`LSUIElement`) app.

First launch may show a Gatekeeper warning since the app isn't notarized — see Troubleshooting below.

## Settings

Open via the "Settings…" link in the panel footer (or ⌘, while the app is focused):

- **ddev path** — leave blank to auto-detect (`/opt/homebrew/bin/ddev`, `/usr/local/bin/ddev`,
  `/opt/local/bin/ddev`, in that order). Set this if your `ddev` lives somewhere else. Restart the app
  after changing it.
- **Auto-refresh interval** — how often the panel re-runs `ddev list -j` while open (default 15s,
  5–300s range). Keep this generous; `ddev list` spawns a real process every time.
- **Launch at login** — registers/unregisters the app with `SMAppService`.

## Troubleshooting

**"ddev executable not found" / empty project list.**
A GUI app launched from Finder only inherits `PATH=/usr/bin:/bin:/usr/sbin:/sbin` — it does **not** see
your shell's Homebrew PATH. This app works around that by setting an explicit PATH
(`/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`) for every command it runs, and by
checking a list of common `ddev` install locations. If `ddev` lives somewhere unusual, set its path in
Settings and restart the app.

**Engine badge shows red / "Container engine down".**
The active backend (shown by name once detected) isn't reachable. If a **Start …** button appears next
to the badge, click it — it runs `colima start` for Colima, or opens the Docker Desktop / OrbStack /
Rancher Desktop app for those. Otherwise start your engine manually, then hit the refresh button in the
panel. The app finds the `docker` CLI in Homebrew's directories as well as OrbStack's (`~/.orbstack/bin`),
Rancher Desktop's (`~/.rd/bin`), and Docker Desktop's bundled location — if yours lives somewhere else,
there's currently no override for it (only `ddev`'s path is configurable in Settings).

**App not visible in the menu bar.**
macOS can hide menu bar icons when the bar is full, or a third-party tool like Bartender can tuck it
away — check there first. The app has no Dock icon by design (`LSUIElement`), so Cmd-Tab won't surface
it either; use the menu bar or Activity Monitor to find it.

**"App can't be opened because it is from an unidentified developer."**
Expected — the build is ad-hoc signed, not notarized with an Apple Developer ID. Right-click the app in
Finder → **Open**, then confirm in the dialog. You only need to do this once per machine.

**A start/stop action fails with no obvious reason.**
Open the **Log** popover in the panel footer — it keeps the last 50 action results (persisted across
restarts) including the real `ddev` error text, which is easy to miss if you only glance at the inline
error banner.

## Architecture (for contributors)

A Swift Package (`DDEVKit`) holds all the logic — parsing `ddev list -j`'s JSON-lines output, wrapping
the CLI (`start`/`stop`/`restart`/`poweroff`), probing the container engine, and an `@Observable`
`ProjectStore` that the SwiftUI layer (`App/Sources`) only renders and dispatches to. Every command goes
through a `CommandRunner` protocol, so the library is fully unit-testable with a mock runner — no `ddev`
installation required to run `swift test` (one integration test is skipped automatically if `ddev` isn't
found).

```
Sources/DDEVKit/      — library: parsing, CommandRunner/ProcessRunner, DDEVService, EngineProbe,
                        ContainerEngineController, ProjectStore
Tests/DDEVKitTests/   — unit tests + recorded ddev-list.jsonl fixtures
App/Sources/          — SwiftUI views: DDEVManagerApp, PanelView, ProjectRow, EngineBadge, LogView,
                        SettingsView, TerminalLauncher
App/Assets.xcassets/  — app icon + menu bar wordmark (generated by scripts/generate_icons.swift)
scripts/build.sh      — generate, test, build Release, ad-hoc sign
scripts/generate_icons.swift — regenerates the icon PNGs if you want to change the design
```

Run tests: `swift test`. Regenerate the Xcode project after changing `project.yml` or adding source
files: `xcodegen generate`.
