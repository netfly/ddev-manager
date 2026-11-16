# AGENTS.md

Notes for coding agents working on DDEV Manager (macOS menu-bar app, Swift 6, macOS 14+).

## Layout

- `Sources/DDEVKit/` — SwiftPM library: ddev/docker CLI wrappers, models, parsing. Unit-tested.
- `App/` — the SwiftUI app target (`App/Sources`, `App/Info.plist`, assets).
- `Tests/DDEVKitTests/` — unit tests + recorded ddev/docker fixtures.
- `project.yml` — XcodeGen spec; **source of truth** for the Xcode project and `App/Info.plist`.
- `scripts/build.sh` — xcodegen → `swift test` → Release build → ad-hoc sign into `dist/`.
- `scripts/package.sh` — build + DMG (`dist/DDEVManager-<version>.dmg`).

`DDEVManager.xcodeproj`, `build/`, `dist/` are generated and git-ignored — never edit them.

## Commands

- Tests: `swift test`
- Regenerate Xcode project (after editing `project.yml` or adding files): `xcodegen generate`
- Full build: `./scripts/build.sh` · DMG: `./scripts/package.sh`

## Bumping the version

Versioning follows [SemVer](https://semver.org); the changelog follows Keep a Changelog.
Only bump on `main`.

Change these, and nothing else:

1. `project.yml`
   - `targets.DDEVManager.info.properties.CFBundleShortVersionString` → new version (e.g. `"0.2.0"`)
   - `targets.DDEVManager.settings.base.MARKETING_VERSION` → same version
   - `targets.DDEVManager.info.properties.CFBundleVersion` → increment the build number by 1
2. `App/Info.plist` — do not hand-edit; run `xcodegen generate`, which rewrites it from `project.yml`.
   Check that `CFBundleShortVersionString` and `CFBundleVersion` now match, and commit it.
3. `CHANGELOG.md` — rename the `## [Unreleased]` contents into `## [X.Y.Z] - YYYY-MM-DD`
   and leave a fresh empty `## [Unreleased]` above it.

Then:

4. `swift test` (or `./scripts/build.sh`) must pass.
5. Commit (`Version X.Y.Z`) and tag (annotated, like `v0.1.0`): `git tag -a vX.Y.Z -m "Version X.Y.Z"`.

Not needed: the About view and `scripts/package.sh` read the version from the built bundle's
`Info.plist` at runtime; the DMG name follows automatically.
