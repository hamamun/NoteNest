NoteNest **{{VERSION}}** — local-first notes and checklists for Windows and
Android, with sync through a private GitHub repository. No account, no
subscription, no telemetry.

### Try it

| File | Platform | Notes |
|------|----------|-------|
| `NoteNest-Setup-{{VERSION}}.exe` | Windows 10/11 x64 | Per-user install, no admin rights. Unsigned → SmartScreen: *More info → Run anyway*. |
| `NoteNest-{{VERSION}}-windows-x64.zip` | Windows x64 | Portable: unzip and run `notenest.exe`. |
| `app-release.apk` | Android 7.0+ | Release build, **not** signed with a Play key. `adb install -r app-release.apk` or sideload. |

### Highlights
- Everything works offline; SQLite on-device is the source of truth
- Private GitHub repo sync as plain Markdown, with tombstones so deletes stay deleted
- Conflicts keep both versions — never merged, never overwritten
- Optional PIN lock, encrypted backups, and encrypted note bodies

### Before you install
- Back up any existing notes if you are coming from another app.
- Create a **fine-grained** GitHub token scoped to one **private** repo with
  *Contents: Read and write* — the full walkthrough is in the
  [README](https://github.com/hamamun/NoteNest#setting-up-sync).
- Binaries here are built by CI and are not code-signed. If you would rather
  not trust a stranger's binary, the README's
  [build-from-source](https://github.com/hamamun/NoteNest#build-from-source)
  section is three commands long.

Full change list: [CHANGELOG.md](https://github.com/hamamun/NoteNest/blob/main/CHANGELOG.md)

<!-- Maintainer: replace this block with the CHANGELOG entries for this
version, and delete the placeholder lines above that do not apply. -->
