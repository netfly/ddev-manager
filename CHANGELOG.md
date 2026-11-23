# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-11-23

### Added

- Daily check for new ddev releases with an update banner in the panel

## [0.1.0] - 2026-11-15

### Added

- Parse ddev list -j output into DDEVProject models
- Add DDEVService wrapping the ddev CLI
- Add ProcessRunner with explicit PATH and timeout
- Probe docker/colima engine state
- Add observable ProjectStore
- Menu bar panel listing and controlling ddev projects
- DDEV wordmark icon, stop-from-paused, search filter, Finder button
- Add ColimaController, bulk start, and ProjectStore log ring buffer
- Start Colima button, Start all stopped, and Log popover
- Sort project list by status (running first), name as tiebreak
- Menu bar icon = compact D monogram badge (was DDEV wordmark)
- Persist action log across restarts (50 entries), left-align log text
- Detect and support Docker Desktop, OrbStack, Rancher Desktop, Colima
- Footer Log/Settings/Quit as icon buttons with tooltips
- Confirm before quitting the app
- Confirm before Power off all
- About popover (name, version, build date, MM Consulting credit + link)
- About credit line — heart + original sparkle mark + MM Consulting
- On-demand engine + project detail data layer
- Engine and per-project detail popovers, compact row icons
- Light/Dark/System appearance override
- Ddev ssh + database GUI buttons for running projects
- Scripts/package.sh builds a distributable DMG installer
- App and menu bar icons from the DDEV logo

### Changed

- Init repo with gitignore
- Add DDEVKit swift package
- Record ddev list -j fixtures
- Stop tracking build/ derived-data output
- Remove Start all stopped feature
- Ui: double panel list max height (420 -> 840)
- Ui: reduce panel list height 840 -> 560
- Add release build and ad-hoc signing script
- Add README
- Gitignore .idea/
- Open-source README and MIT license
- Untrack .idea and .hermes, ignore them
- Add screenshot to README

### Fixed

- Use fixed height for project list so panel actually grows taller
- Live Log popover, and bring Settings window to front via NSApp.activate
- Settings layout (vertical labels, text-field auto-refresh)
- Center menu bar D glyph on ink bounds, not font metrics
- Confirmations use popover not confirmationDialog
