# Changelog

All notable changes to **NoteNest** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Version numbers are published in `pubspec.yaml` as `MAJOR.MINOR.PATCH+BUILD`.

## [Unreleased]

### Added
- Placeholder for the `v1.6` line: restore-from-backup.

## [1.5.0] - 2026-08-31

Polish release: motion, Material You, and an undo safety net.

### Added
- Shared-element transition: opening a card flies it into the item screen and
  back on pop, skipped for reduced-motion users (MOT-01). Card view switches
  (Grid / List / Compact / Rows) cross-fade, and colour changes on cards and
  the item background animate instead of snapping (MOT-02, MOT-03).
- Optional Material You wallpaper colours on Android 12+ (Appearance →
  "Wallpaper colours"), with the built-in palette as fallback everywhere
  else, and an optional true-black dark theme for AMOLED panels (THM-01,
  THM-02).
- Undo safety net: Edit Mode gains undo/redo controls backed by the platform
  undo stack (IME and Ctrl+Z agree with the buttons), and every pin, colour,
  archive, trash and restore — single or multi-select — confirms with a
  five-second Undo snackbar that reverts to the previous value (UND-01,
  UND-02).

### Fixed
- The session auto-lock timer now resets on in-app activity — taps, drags,
  scrolls, physical key presses and editor typing keep the session open, so
  notes no longer lock while you are actively working in them (PIN-05). The
  lock still fires after real inactivity, and a backgrounded app still locks
  once its deadline passes.
- The Windows build no longer fails: Edit Mode's undo/redo now uses the
  framework's built-in `UndoHistoryController` (wired through
  `TextField.undoController`, so IME undo, Ctrl+Z and the app bar buttons
  still share one history), the item app bar accepts a nullable background
  colour, and wheel-scroll activity is detected with the version-safe
  `onPointerSignal` + `PointerScrollEvent` pair (UND-01, PIN-05).

## [1.0.0] - 2026-08-27

First public release. Ships for **Windows x64** and **Android**; iOS, macOS and
Linux runners are deliberately out of scope for this version.

### Added

**Core**
- Local-first storage: notes, checklists, images and settings in SQLite via
  `drift`; the app is fully functional with no network connection.
- Note and checklist creation flow with colour, pin, archive and trash.
- View / Edit modes with a Markdown preview (headings, bold, italics, inline
  code, lists) rendered by a self-contained widget.
- Search scoped to the current workspace, three entry filters, five sort
  modes, four card layouts, and an adjustable note text size.
- Clickable links in note bodies, and a keep-screen-awake toggle for reading.

**Checklists**
- Text-based checked-state matcher, so a re-typed or re-ordered item keeps its
  checkmark; duplicates and unicode handled by rule rather than by id.

**Images**
- Attach from disk or camera, local storage with generated thumbnails, an
  image strip in View mode, and mirrored upload during sync.

**Sync (private GitHub repository)**
- Contents-API sync engine: one Markdown file per entry with YAML front matter,
  plus `images/`, `thumbnails/`, `.tombstones/` and `backups/` trees.
- Tombstone protocol that prevents deleted notes from being resurrected by an
  offline device; tombstones are always pulled before anything is pushed.
- Conflict policy: never merge, never overwrite — both versions are kept and
  the loser is stored as a labelled conflict copy.
- Fine-grained personal access token kept in the OS keychain; sync refuses to
  enable against a public repository; auto-sync plus a manual cloud button.
- Optional encryption of note bodies before upload.

**Backup & export**
- Scheduled weekly/monthly ZIP backups into the repo, plus save-to-disk.
- Optional AES-256-GCM encrypted backups with PBKDF2 key derivation.
- Markdown-folder import as the recovery path in this version.
- PDF and TXT export, with an optional `NotoSans` font slot for Bengali, Hindi,
  Arabic and CJK output.

**Privacy lock**
- Optional 4-digit PIN protecting notes, lists or both, per device, with
  1/5/15-minute auto-lock and immediate lock when the app is closed.
- Salted, hashed PIN storage; Archive and Trash stay reachable.

**Engineering**
- Redacting logger that scrapes anything shaped like a GitHub token.
- Stable-string enums so stored values survive enum reordering.
- Setup scripts (`tool/setup.ps1`, `tool/setup.sh`) that generate the platform
  runners, restore the source over Flutter templates, run codegen, and analyze.
- Inno Setup script for the Windows installer.
- Unit tests: checklist matcher, sync decision table (all 32 input
  combinations), entry file codec round-trip, core utilities, PIN lock.
- CI: `flutter analyze` and `flutter test` on Linux and Windows for every push
  and pull request; a separate workflow builds the Windows installer and the
  Android APK on tags and drafts a GitHub Release with them.
- Repository metadata: MIT license, this changelog, contributing guide,
  security policy, issue and pull-request templates.

### Known limitations
- Restore-from-backup is not implemented; unpack a backup and re-import the
  Markdown folder instead.
- Platform runners for iOS/macOS/Linux are not generated or tested.
- Windows binaries are not code-signed, so SmartScreen warns on first launch.
- Content deleted from the repo can remain in Git history; use encrypted sync
  if that matters to you.

[Unreleased]: https://github.com/hamamun/NoteNest/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/hamamun/NoteNest/compare/v1.0.0...v1.5.0
[1.0.0]: https://github.com/hamamun/NoteNest/releases/tag/v1.0.0
