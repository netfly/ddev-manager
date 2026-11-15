# DDEV Manager

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS 14+](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)

A lightweight macOS menu bar app for managing [DDEV](https://ddev.com) projects — start, stop, restart,
open in the browser, open the project folder, and power everything off — without touching a terminal.

![menu bar icon: a rounded-square "D" monogram badge](App/Assets.xcassets/MenuBarIcon.imageset/menubar@3x.png)

No Dock icon, no daemon: it's a thin SwiftUI panel that shells out to the real `ddev` CLI you already
have installed.

Open source under the [MIT License](LICENSE). Not affiliated with the DDEV project.

## Features

- **Project list**, sorted with running projects first, then starting/paused/stopped, alphabetically
  within each group.
- **Search field** to filter the list by name.
- **Per-project actions**: Start, Stop, Restart, open primary URL in the browser, open the project
  folder in Finder (always visible, uses the real absolute path `ddev` reports), open in your terminal,
  open Mailpit, copy URL (context menu / right-click for the last few).
- **Running projects** additionally get a **`ddev ssh`** button (opens a shell in the `web`
  container in your preferred terminal app) and a **database** button that launches your preferred
  on-host DB GUI through ddev's own host command (`ddev sequelace`, `ddev tableplus`,
  `ddev tablepro`, `ddev querious`, `ddev dbeaver`, `ddev mysqlworkbench`, or the phpMyAdmin /
  Adminer add-ons). Both are also in the right-click menu.
- **Paused projects** can be resumed (Start) or fully stopped (Stop).
- **Engine status badge** showing whether the container backend is reachable, with version — works
  with Docker Desktop, OrbStack, Rancher Desktop, or Colima, detected automatically via the active
  `docker context`. If it's down, a **Start …** button appears, naming and launching whichever
  backend is actually in use (`colima start`, or opening the Docker Desktop / OrbStack / Rancher
  Desktop app). An **ⓘ** button next to the badge (the badge text itself works too) opens an engine
  popover with the detected backend, the active `docker context` and its socket endpoint, the ddev
  toolchain versions (ddev, docker, docker API, buildx, mutagen, global ddev dir), and live
  CPU/memory totals across all running containers.
- **Per-project details popover** (ⓘ in each row) — PHP version, webserver type, database
  engine/version, Node.js version, docroot, performance mode and mutagen sync status, every
  container with health/uptime/restart count and live CPU+memory, volume disk usage (data vs.
  regenerable mutagen sync cache), and a warning when the project still carries images from an
  older ddev release. Loaded on demand only (`ddev describe` costs one process per project), with
  its own reload button.
- **Power off all** — runs `ddev poweroff`.
- **Action log** — a popover with the last 50 actions (success/failure with the real error text),
  persisted across restarts, since `ddev start` failures can be verbose and easy to miss.
- **Settings**: override the `ddev` executable path, tune the auto-refresh interval, pick the
  appearance (System / Light / Dark), launch at login.
- **About popover**: app name, version/build number, build date, and a link to
  [markus-meier.consulting](https://www.markus-meier.consulting).
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
git clone https://github.com/netfly/ddev-manager.git
cd ddev-manager
./scripts/build.sh
```

This generates the Xcode project, runs the `DDEVKit` unit tests, builds a Release binary, and ad-hoc
signs it. Output: `dist/DDEVManager.app`.

The app is **ad-hoc signed, not notarized** — fine for building and running it yourself, not for
distributing to other machines without adjustment.

## Package an installer (DMG)

```bash
./scripts/package.sh                # full build + tests + DMG
./scripts/package.sh --skip-build   # reuse the existing dist/DDEVManager.app
```

Output: `dist/DDEVManager-<version>.dmg` — a drag-to-install disk image containing the app, an
`Applications` symlink, and an `INSTALL.txt` with requirements, the Gatekeeper step, and uninstall
instructions. The script prints the DMG's size and `sha256` (handy for a Homebrew cask or a release
note). Attach it to a GitHub release, or just hand the file over.

**Without an Apple Developer account** the DMG stays ad-hoc signed, so macOS quarantines it on the
recipient's Mac and refuses the first launch ("damaged" / "unidentified developer"). They clear it
once:

```bash
xattr -dr com.apple.quarantine /Applications/DDEVManager.app
```

(or right-click → Open, or System Settings → Privacy & Security → "Open Anyway"). This is spelled
out in the generated `INSTALL.txt`.

**With a Developer ID** ($99/year Apple Developer Program) the same script produces a clean,
double-click-installable DMG — no warnings, nothing for the recipient to do:

```bash
# once: store an app-specific password for the notary service
xcrun notarytool store-credentials ddevmanager \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>

NOTARY_PROFILE=ddevmanager ./scripts/package.sh
```

`SIGN_IDENTITY` is auto-detected from the keychain ("Developer ID Application: …") or can be set
explicitly; the script then signs with hardened runtime + secure timestamp, signs the DMG, submits
it for notarization and staples the ticket.

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
- **Appearance** — System (follow macOS), Light, or Dark. Applied app-wide via `NSApp.appearance`,
  so it covers the panel, every popover, and the Settings window; takes effect immediately, no
  restart needed.
- **Launch at login** — registers/unregisters the app with `SMAppService`.
- **Terminal app** — which terminal the "Open in Terminal" and `ddev ssh` actions use: auto-detect,
  or pick Terminal, iTerm2, Warp, Ghostty, kitty, Alacritty, WezTerm, Hyper, Tabby. Apps that
  aren't installed are marked. macOS has no portable "run this command in a terminal" API, so the
  app writes a small `.command` script and hands it to the chosen app via `open -a` (verified with
  Terminal.app and Warp); auto-detect falls back to Terminal.app, which always exists.
- **Database client** — which GUI the database button opens, via ddev's own host command:
  Sequel Ace, TablePlus, TablePro, Querious, DBeaver, MySQL Workbench, or the browser-based
  phpMyAdmin / Adminer add-ons (see
  [ddev's database GUI docs](https://docs.ddev.com/en/stable/users/usage/database-management/#database-guis)).
  Auto-detect picks the first installed app. The ddev command only exists when the client is
  actually installed — MySQL Workbench additionally needs
  `cp ~/.ddev/commands/host/mysqlworkbench.example ~/.ddev/commands/host/mysqlworkbench`, and
  phpMyAdmin/Adminer need `ddev add-on get ddev/ddev-phpmyadmin` / `ddev-adminer`.

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
                        ContainerEngineController, DockerInspector, DDEVDescribe/DDEVVersionInfo
                        parsers, ProjectDetails/EngineDetails, ExternalApps
                        (TerminalApp/DatabaseClient), ProjectStore
Tests/DDEVKitTests/   — unit tests + recorded ddev/docker fixtures (list, describe, version,
                        stats, inspect, system df -v)
App/Sources/          — SwiftUI views: DDEVManagerApp, PanelView, ProjectRow, EngineBadge,
                        EngineInfoView, ProjectDetailView, DetailRow, CompactIconButtonStyle,
                        AppearanceMode, LogView, SettingsView,
                        AboutView, ConfirmationPopover, TerminalLauncher
App/Assets.xcassets/  — app icon + menu bar wordmark (generated by scripts/generate_icons.swift)
scripts/build.sh      — generate, test, build Release, ad-hoc sign
scripts/package.sh    — build + DMG installer (optional Developer ID signing/notarization)
scripts/generate_icons.swift — regenerates the icon PNGs if you want to change the design
```

Detail data sources: `ddev describe <name> -j` (stack/performance fields) plus `docker context
inspect`, `docker stats --no-stream`, `docker ps`/`docker inspect` filtered on ddev's
`com.ddev.site-name` label, and `docker system df -v` (volume sizes, attributed per project via
the `com.docker.compose.project` label). All of it runs only when a popover is opened, never
during the panel's auto-refresh.

Run tests: `swift test`. Regenerate the Xcode project after changing `project.yml` or adding source
files: `xcodegen generate`.

## Contributing

Issues and pull requests are welcome at
[github.com/netfly/ddev-manager](https://github.com/netfly/ddev-manager). Please run `swift test` before
opening a PR, and keep changes focused — one feature or fix per PR. For larger changes, open an issue
first to discuss the approach.

## License

[MIT](LICENSE) © Markus Meier. DDEV is a trademark of its respective owners; this project is an
independent, unofficial companion app.
