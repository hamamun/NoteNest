# NoteNest — Master Build Checklist (Single-Shot Build Reference)

This file is the **implementation contract**. It was produced by reading every line of:

```text
local_first_notes_app_plan.md               (3879 lines)
local_first_notes_app_requirements_audit.md ( 823 lines)
```

Every requirement in those two files appears below with a stable ID.
If something is not in this file, it is not in Version 1.

> ## Implementation status — v1.0.0 (228 requirements built)
>
> `[~]` = **implemented in code.** This checklist was written in a sandbox that
> had no Flutter SDK, so the items were originally marked against the source
> rather than against a running app. The project has since been built with the
> stable Flutter toolchain and the five suites in `test/` cover the logic that
> is expensive to get wrong (checklist matcher, anti-resurrection decision
> table, file codec round-trip, core utilities, PIN lock).
>
> Nothing has been moved to `[x]` automatically. `[x]` means *a human ran it on
> a device and it behaved* — tick those off yourself as you walk the QA list,
> and add the date next to the ID.
>
> `[ ]` on a **QA-** item = manual check on Windows/Android still to be run.
> `[ ]` on a **LATER** item = deliberately out of scope for v1, do not build.
>
> Counts: 228 implemented · 26 QA steps to run · 13 deferred.
>
> First step: `powershell -ExecutionPolicy Bypass -File tool\setup.ps1`
> (or `bash tool/setup.sh` on Linux/macOS)

## Legend

```text
[ ]  not started
[~]  in progress
[x]  done and manually verified
```

```text
MUST      hard requirement, build fails review without it
SHOULD    strong default, deviate only with a written reason
LATER     explicitly deferred to v2/v3, do not build now
GAP       not specified in the source docs; default chosen here to avoid blocking
```

---

## 0. Locked Decisions (do not re-litigate)

| # | Decision | Value |
|---|----------|-------|
| DEC-1 | Names | NoteNest / `notenest` / `com.notenest.notenest` |
| DEC-2 | Export formats | PDF + TXT only |
| DEC-3 | Platforms | Windows + Android only |
| DEC-4 | Checklist state | matched by line TEXT, never position |
| DEC-5 | Encryption | secure token + private-repo check + optional encrypted backup |

Stack: Flutter · Dart · Drift/SQLite · GitHub Contents API · flutter_secure_storage · Material 3.

---

## 1. Project Setup — `P`

- [~] **P-01** MUST `flutter create` with project name `notenest`, org producing applicationId `com.notenest.notenest`.
- [~] **P-02** MUST enable only Windows + Android platforms. Do not generate/maintain macOS, Linux, iOS, or Web folders.
- [~] **P-03** MUST Android app label = `NoteNest`; Windows window title = `NoteNest`.
- [~] **P-04** MUST `.gitignore` covers build output, `*.g.dart` is committed or generated in CI (pick one and be consistent — default: commit generated Drift files).
- [~] **P-05** MUST dependencies:
  ```text
  drift, drift_flutter (or sqlite3_flutter_libs + path_provider), drift_dev, build_runner
  flutter_secure_storage
  http                          -> GitHub Contents API
  flutter_markdown              -> note View Mode rendering
  flutter_staggered_grid_view   -> masonry grid
  pdf + printing                -> PDF export
  file_picker                   -> Windows image pick + Save As
  image_picker                  -> Android gallery
  archive                       -> zip for backup/multi-export
  crypto + pointycastle (or cryptography) -> PBKDF2 + AES-256-GCM backup encryption
  url_launcher                  -> clickable URLs
  uuid or ulid                  -> entry IDs
  path, intl, shared_preferences (or Drift settings table)
  ```
- [~] **P-06** SHOULD folder structure:
  ```text
  notenest/lib/
    main.dart
    app/            app_theme.dart, responsive_layout.dart, router.dart
    features/
      notes/        note_model.dart, home_page.dart, item_page.dart, widgets/
      storage/      local_database.dart, entry_repository.dart, image_store.dart
      sync/         github_auth.dart, github_client.dart, sync_engine.dart,
                    conflict_resolver.dart, tombstone_store.dart
      backup/       backup_service.dart, backup_crypto.dart
      export/       export_service.dart, pdf_builder.dart, txt_builder.dart
      settings/     settings_page.dart, settings_repository.dart
  ```
- [~] **P-07** GAP Device identity: generate a ULID device_id on first launch, store locally, plus a human device name (`hostname` / Android model). Needed by tombstones, backup filenames, conflict titles.
- [~] **P-08** GAP IDs: use ULID (sortable, collision-safe) for entries, images, checklist items, delete revisions.
- [~] **P-09** GAP All timestamps stored UTC ISO-8601; displayed in local time.

---

## 2. Database Schema (Drift) — `D`

- [~] **D-01** MUST table `entries`:
  ```text
  id TEXT PK
  type TEXT              note | checklist
  title TEXT
  body TEXT              markdown for notes, raw multiline text for checklists
  color_key TEXT         default | red | orange | yellow | green | teal | blue | purple | pink | gray
  is_pinned BOOL
  pinned_at INT NULL
  pin_order INT NULL           LATER, column may exist unused
  location TEXT                active | archive | trash | deleted
  previous_location_before_trash TEXT NULL
  checkboxes_visible_in_view BOOL   default true, checklists only
  created_at INT
  updated_at INT
  content_updated_at INT
  metadata_updated_at INT
  last_viewed_at_local INT NULL     LOCAL ONLY, never synced
  archived_at INT NULL
  trashed_at INT NULL
  permanently_deleted_at INT NULL
  content_deleted BOOL
  local_changed BOOL
  last_synced_at INT NULL
  last_remote_sha TEXT NULL
  last_local_hash TEXT NULL
  sync_status TEXT             synced | pending | pending_delete | conflict_review | error
  ```
- [~] **D-02** MUST table `checklist_items`: `id, entry_id, text, checked, sort_order, created_at, updated_at, deleted_at`.
- [~] **D-03** MUST table `entry_images`: `id, entry_id, file_name, local_path, remote_path, mime_type, size_bytes, width, height, created_at, deleted_at, local_changed, sync_status`.
- [~] **D-04** MUST table `tombstones`: `entry_id, type, deleted_at, deleted_by_device_id, delete_revision_id, last_known_note_path, last_known_image_ids, synced, remote_sha`.
- [~] **D-05** MUST table `sync_config`: `id, sync_enabled, github_owner, github_repo, github_branch, last_sync_at, last_sync_status, last_remote_commit`. **No token column, ever.**
- [~] **D-06** MUST table `app_settings` (or shared_preferences): `card_view_mode, content_font_scale, clickable_urls_enabled, sort_mode, theme_mode, backup_enabled, backup_frequency, last_backup_at, last_backup_status, backup_encryption_enabled, device_id, device_name`.
- [ ] **D-07** LATER table `devices` (`device_id, device_name, platform, first_seen_at, last_sync_at`) — for smarter tombstone retention. Do not build.
- [~] **D-08** MUST schema version 1 + migration strategy in place from day one.
- [~] **D-09** MUST indexes on `entries(location, is_pinned, updated_at)` and `checklist_items(entry_id, sort_order)`.
- [~] **D-10** MUST DB file lives in platform app-support dir via `path_provider`.

---

## 3. Core Behaviour: Notes & Lists — `N`

- [~] **N-01** MUST two content types only: `note` and `checklist`.
- [~] **N-02** MUST note fields: title, markdown body, images, color. No video, no file attachments.
- [~] **N-03** MUST checklist fields: title, multiline body lines, images, color.
- [~] **N-04** MUST saved item always opens in **View Mode** first.
- [~] **N-05** MUST note View Mode renders Markdown, is read-only, text still selectable/copyable.
- [~] **N-06** MUST note Edit Mode: title + body editable, **autosave locally**.
- [~] **N-07** GAP Autosave policy: debounce 800 ms after typing stops, plus save on mode switch, back navigation, and app pause/close.
- [~] **N-08** MUST checklist Edit Mode is a plain multiline editor — no per-item add/delete/reorder buttons.
  ```text
  add item    = new line
  delete item = delete line
  edit item   = edit line text
  reorder     = cut/paste line
  ```
- [~] **N-09** MUST checklist View Mode renders every **non-empty** line as a checkbox row.
- [~] **N-10** MUST in checklist View Mode the user may check/uncheck only; cannot edit text, add, delete, or reorder.
- [~] **N-11** MUST empty-title items are allowed; card falls back to first body line.

---

## 4. Checklist Checkbox Toggle — `K`

- [~] **K-01** MUST toggle exists **only** for checklists, **only** in View Mode.
- [~] **K-02** MUST On = checkbox before every non-empty line; Off = plain readable lines.
- [~] **K-03** MUST toggle never converts the item into a note.
- [~] **K-04** MUST checked states are preserved while checkboxes are hidden.
- [~] **K-05** MUST text stays selectable/copyable in both toggle states.
- [~] **K-06** MUST persisted per item in `entries.checkboxes_visible_in_view`; default **On**.
- [~] **K-07** MUST this field syncs (it is item metadata, not a device preference).
- [~] **K-08** MUST icons: checked-box icon = on, plain-lines icon = off.
- [~] **K-09** MUST placement: desktop item toolbar near View/Edit; mobile top bar beside Edit, else first entry in ⋮.
- [~] **K-10** MUST do not confuse with home card view mode (grid/list/compact) — different concepts, different icons.

---

## 5. Checklist Checked-State Matching (DEC-4) — `M`

- [~] **M-01** MUST match by normalized line text, never by index.
- [~] **M-02** MUST normalization = trim ends + collapse internal whitespace runs to one space + **case-sensitive**.
- [~] **M-03** MUST algorithm on save:
  ```text
  1. old items -> Map<normalizedText, Queue<bool checked>> in old order
  2. split editor text into lines, drop empty lines
  3. for each new line in order:
       if queue for that text is non-empty -> pop -> reuse checked
       else -> checked = false
  4. rewrite checklist_items with new order (sort_order = index)
  ```
- [~] **M-04** MUST moved line with unchanged text keeps its checkmark.
- [~] **M-05** MUST any text change makes the line unchecked.
- [~] **M-06** MUST duplicates consumed in order of appearance; fewer new copies than old = first-available-match wins.
- [~] **M-07** MUST `checklist_items.text` is the match identity; `sort_order` is display only.
- [~] **M-08** MUST unit tests for: reorder, edit, duplicate-shrink, duplicate-grow, all-new, all-deleted, whitespace-only change, case change.

---

## 6. Copy Text — `CP`

- [~] **CP-01** MUST desktop: mouse selection, Ctrl+C, right-click context menu Copy.
- [~] **CP-02** MUST mobile: long-press native selection + copy menu.
- [~] **CP-03** MUST **Copy All** button in View Mode for notes and checklists.
- [~] **CP-04** MUST copy options: copy selection / copy body only / copy title + body.
- [~] **CP-05** MUST checklist Copy All default format = plain lines without checkbox marks:
  ```text
  Rice
  Milk
  Tea
  ```
- [ ] **CP-06** LATER optional `[ ] / [x]` copy format setting.
- [~] **CP-07** MUST View Mode must never block copying.
- [~] **CP-08** MUST on mobile checklist, checkbox tap area and text long-press area must not fight each other.

---

## 7. Images — `IMG`

- [~] **IMG-01** MUST images only. Allowed: JPG/JPEG, PNG, WebP.
- [~] **IMG-02** MUST reject video, PDF, documents, and any generic file — enforce in the picker filter **and** re-validate by extension + magic bytes after pick.
- [~] **IMG-03** MUST entry-level images in v1 (image strip attached to the item), not inline Markdown images.
- [ ] **IMG-04** LATER inline `![image](image://image-id)` syntax.
- [~] **IMG-05** MUST store original in local app images folder; save metadata row in `entry_images`.
- [~] **IMG-06** MUST generate a thumbnail for card preview.
- [~] **IMG-07** MUST images visible in View Mode and on the card preview.
- [~] **IMG-08** MUST images sync to GitHub `images/`, thumbnails to `thumbnails/`.
- [~] **IMG-09** SHOULD compress/downscale large images before sync; warn on very large files.
- [~] **IMG-10** MUST Windows picker = `file_picker` with image-only filter; Android = `image_picker` gallery.
- [ ] **IMG-11** LATER drag-and-drop, clipboard paste, camera capture.
- [~] **IMG-12** MUST images render as clean rounded thumbnails; tap opens full view.
- [~] **IMG-13** GAP Deleting an image from an item marks `deleted_at`, removes local file after successful sync-delete.

---

## 8. Color — `COL`

- [~] **COL-01** MUST per-item color, stored in `entries.color_key`.
- [~] **COL-02** MUST palette: default, red, orange, yellow, green, teal, blue, purple, pink, gray.
- [~] **COL-03** MUST color shows on card background and on the open item screen.
- [~] **COL-04** MUST color syncs across devices.
- [~] **COL-05** MUST desktop = small popover near palette icon; mobile = bottom sheet of color circles.
- [~] **COL-06** GAP Each color needs a light-mode and dark-mode variant; text contrast must stay readable in both.

---

## 9. Pin, Sort, Search — `S`

- [~] **S-01** MUST pin/unpin any note or list.
- [~] **S-02** MUST pinned state syncs both directions.
- [~] **S-03** MUST pinned items render above unpinned in Home and Archive.
- [~] **S-04** MUST pinned value preserved through archive/restore.
- [~] **S-05** SHOULD Trash ignores pinned ordering but keeps the stored value.
- [~] **S-06** MUST default sort = pinned first, then `updated_at` desc.
- [~] **S-07** MUST edits bump `updated_at`, which syncs, so edited items float to top on every device.
- [~] **S-08** MUST sort options: Recently edited (default) · Created newest · Created oldest · Title A–Z · Recently viewed (local only).
- [~] **S-09** MUST `last_viewed_at_local` is written on open but **never** synced and never bumps `updated_at`.
- [~] **S-10** MUST sort mode + card view mode are per-device local preferences, not synced.
- [~] **S-11** MUST maintain `content_updated_at` (title/body/checklist/image) vs `metadata_updated_at` (color/pin/archive/trash) separately; v1 sorts on `updated_at`.
- [~] **S-12** MUST local search over title + body, case-insensitive, scoped to the current screen (Home/Archive/Trash).
- [~] **S-13** GAP Search matches checklist line text too (body holds the lines, so this is free).
- [~] **S-14** GAP Search is debounced 250 ms; empty query restores the normal list.

---

## 10. Archive & Trash — `T`

- [~] **T-01** MUST `entries.location` is the single source of truth: `active | archive | trash | deleted`.
- [~] **T-02** MUST an item can never be archived and trashed simultaneously.
- [~] **T-03** MUST screens: Home (`active`), Archive (`archive`), Trash (`trash`), Settings. `deleted` never renders.
- [~] **T-04** MUST All/Notes/Lists filters work inside Home, Archive, and Trash.
- [~] **T-05** MUST Archive action → `location=archive, archived_at=now, trashed_at=null, previous_location_before_trash=null, metadata_updated_at=now, local_changed=true`. Content, images, color, checked states all preserved.
- [~] **T-06** MUST Restore from Archive → `location=active, trashed_at=null, previous_location_before_trash=null, archived_at=null, metadata_updated_at=now, local_changed=true`.
- [~] **T-07** MUST Move to Trash from Home → `previous_location_before_trash=active, location=trash, trashed_at=now, metadata_updated_at=now, local_changed=true`.
- [~] **T-08** MUST Move to Trash from Archive → same but `previous_location_before_trash=archive`.
- [~] **T-09** MUST Restore from Trash returns to `previous_location_before_trash`, falling back to `active`; clears `trashed_at` and `previous_location_before_trash`.
- [~] **T-10** MUST Trash item actions: Restore · Move to Home · Move to Archive · Delete forever.
- [~] **T-11** MUST Trash → Archive sets `location=archive, archived_at=now, trashed_at=null, previous_location_before_trash=null`.
- [~] **T-12** MUST Delete Forever is available **only** inside Trash. From Home/Archive the delete action means Move to Trash.
- [~] **T-13** MUST Empty Trash: confirmation dialog → every trash item permanently deleted → tombstone created for each → local body/images removed or queued → GitHub files deleted on next sync.
- [~] **T-14** MUST permanent delete sets `location=deleted, permanently_deleted_at=now, content_deleted=true, local_changed=true, sync_status=pending_delete`.
- [~] **T-15** MUST never hard-delete a row without writing a tombstone first.
- [ ] **T-16** LATER auto-empty-trash after 30 days. v1 is manual only.
- [~] **T-17** MUST destructive actions (Empty Trash, Delete Forever) use a warning icon + confirmation dialog with explanatory text.

---

## 11. Anti-Resurrection / Tombstones — `X` (highest risk area)

- [~] **X-01** MUST every permanent delete writes a local tombstone row.
- [~] **X-02** MUST remote tombstone path `.tombstones/entries/<entry-id>.json` containing:
  ```json
  { "id": "...", "type": "note", "deleted_at": "...", "deleted_by_device_id": "...",
    "delete_revision_id": "...", "last_known_note_path": "notes/<id>.md",
    "last_known_image_ids": ["..."], "reason": "delete_forever" }
  ```
- [~] **X-03** MUST **sync order is fixed**:
  ```text
  1 check internet
  2 fetch remote tombstones FIRST
  3 apply tombstones locally
  4 fetch remote entry changes
  5 merge into local DB
  6 upload local tombstones/deletes
  7 upload local non-deleted changes
  ```
- [~] **X-04** MUST never push local entries before pulling tombstones.
- [~] **X-05** MUST tombstone beats note file — if both exist remotely, the entry is deleted.
- [~] **X-06** MUST a tombstoned original ID is **never** uploaded again.
- [~] **X-07** MUST Delete Forever flow order: mark deleted → create tombstone → remove local files → **PUT tombstone** → DELETE note file → DELETE image files → retry failures later.
- [~] **X-08** MUST offline device returning: applies tombstone, marks local deleted, uploads nothing — **if it has no unsynced edits**.
- [~] **X-09** MUST offline device **with** unsynced edits to a tombstoned entry: apply tombstone to the original ID, do NOT upload it, create a **new-ID recovered conflict copy** with `sync_status=conflict_review`, title like `Recovered conflict - Shopping List - from Laptop - 2026-07-27`.
- [~] **X-10** MUST never blindly recreate a missing remote file. Decision table:
  ```text
  local never synced before        -> upload as new
  synced before, remote missing, tombstone exists -> mark local deleted
  synced before, remote missing, no tombstone     -> remote-delete conflict, ask/flag; never silent re-upload
  ```
- [~] **X-11** MUST compare-and-swap on every write: send `last_remote_sha`; on 409/sha mismatch, pull and merge, never force.
- [~] **X-12** MUST no force overwrite, no force push, no blind PUT.
- [~] **X-13** MUST keep tombstones **forever** in v1.
- [~] **X-14** MUST an entry tombstone also blocks all of that entry's images from ever uploading; delete/quarantine them locally.
- [~] **X-15** MUST Empty Trash creates a tombstone per item, not one bulk marker.
- [~] **X-16** MUST integration tests simulating: delete-on-A-then-B-syncs; delete-on-A-plus-offline-edit-on-B; remote file missing without tombstone; sha conflict mid-push.

---

## 12. GitHub Sync — `G`

- [~] **G-01** MUST remote layout:
  ```text
  notes/<entry-id>.md
  images/<image-id>.<ext>
  thumbnails/<image-id>.jpg
  .tombstones/entries/<entry-id>.json
  meta/index.json
  backups/{weekly,monthly,manual}/
  ```
- [~] **G-02** MUST one file per entry. Never a single combined `notes.json`.
- [~] **G-03** MUST entry file = YAML front-matter (`id, type, title, color, created, updated, deleted, images`) + body. Checklists keep `- [ ] / - [x]` lines in the body.
- [~] **G-04** MUST front-matter must round-trip every synced field, including `is_pinned`, `pinned_at`, `location`, `checkboxes_visible_in_view`, `content_updated_at`, `metadata_updated_at`.
- [~] **G-05** MUST never write `last_viewed_at_local`, sort mode, card view mode, or font scale to the repo.
- [~] **G-06** MUST GitHub **Contents API** for v1 (`GET/PUT/DELETE /repos/{owner}/{repo}/contents/{path}`).
- [ ] **G-07** LATER Git Data API for atomic batch commits.
- [~] **G-08** MUST sync flow: load local instantly → if online, pull remote → merge → push local.
- [~] **G-09** MUST conflict = both sides changed → **never merge, never overwrite** → create conflict copy titled `<title> - conflict from <Device> <date>`.
- [~] **G-10** MUST location/metadata conflicts: apply the location change if only location differs; if content changed on one side and location on the other, keep the content and apply the location when safe; destructive vs unsynced-edit always produces a conflict copy.
- [~] **G-11** MUST manual sync only in v1. Sync button in desktop top bar/sidebar, mobile top bar, and Settings > Sync.
- [~] **G-12** MUST sync button preconditions: sync enabled → token present → internet → run engine → report result.
- [~] **G-13** MUST sync status states: Not connected · Connected · Syncing · Last synced <time> · Sync failed · Reconnect required.
- [~] **G-14** MUST handle and surface: invalid token, repo not found, no permission, branch not found, no internet, rate limit.
- [~] **G-15** MUST persist `last_sync_at`, `last_sync_status`, `last_remote_commit`.
- [ ] **G-16** LATER auto-sync on open / on network return.
- [~] **G-17** GAP Sync must be cancellable and must never run two syncs concurrently (single-flight lock).
- [~] **G-18** GAP Large repo paging: `GET contents` on a directory returns up to 1000 entries — page or use the tree API read-only if exceeded.

---

## 13. Sync Setup & Token Security — `SEC`

- [~] **SEC-01** MUST app is fully usable with sync never configured.
- [~] **SEC-02** MUST Settings > Sync fields: GitHub Sync On/Off · owner · repository · branch (default `main`) · Personal Access Token · Test Connection · Save and Enable Sync · Disconnect.
- [~] **SEC-03** MUST setup flow: paste token → enter owner/repo/branch → Test Connection → on success store token securely, save config, `sync_enabled=true`, enable Sync button.
- [~] **SEC-04** MUST Test Connection calls `GET /repos/{owner}/{repo}` and `GET /repos/{owner}/{repo}/contents?ref={branch}`; verifies token validity, repo existence, access, Contents read/write, branch existence.
- [~] **SEC-05** MUST **repo must be private** — read `private` from the repo response; if public, refuse to enable sync with the message "This repository is public. Use a private repository."
- [~] **SEC-06** MUST sync cannot be enabled until Test Connection passes.
- [~] **SEC-07** MUST token stored **only** in `flutter_secure_storage` under key `github_pat` (Windows Credential Manager / Android Keystore).
- [~] **SEC-08** MUST token never in SQLite, never in a plain file, never in logs or error text, never in exports or backups, never hardcoded.
- [~] **SEC-09** MUST token is masked while typing and **never displayed again** after saving. UI shows `Token: Saved` + `[Replace Token]` `[Remove Token]`.
- [~] **SEC-10** MUST Replace Token tests the new token first; on failure keep the old one unless the user explicitly removes it.
- [~] **SEC-11** MUST **Disable Sync** = `sync_enabled=false`, token kept, data untouched, can re-enable without re-pasting.
- [~] **SEC-12** MUST **Disconnect** = `sync_enabled=false`, token deleted from secure storage, repo config cleared on confirm, local notes untouched.
- [~] **SEC-13** MUST `sync_enabled=true` but token missing → disable sync and show "Reconnect GitHub".
- [~] **SEC-14** MUST document required fine-grained token scopes in-app: single repo, Contents read/write, Metadata read.
- [~] **SEC-15** MUST Settings shows the honest privacy note: deleted content may persist in Git history; do not store passwords or highly sensitive data in v1.
- [~] **SEC-16** MUST note bodies sync as plain Markdown in v1 (no per-note encryption).
- [ ] **SEC-17** LATER encrypted note sync + SQLCipher (v3).

---

## 14. Backup — `B`

- [~] **B-01** MUST backup is separate from sync (snapshot vs live state) and lives in Settings > Backup.
- [~] **B-02** MUST settings: GitHub Backup On/Off · frequency Disabled/Weekly/Monthly · Backup Now · last backup time · last backup status.
- [~] **B-03** MUST backup requires GitHub sync connected; otherwise show "Connect GitHub Sync first".
- [~] **B-04** MUST due-check runs on app open / after sync / on coming online (no server cron).
- [~] **B-05** MUST weekly = last backup older than 7 days; monthly = previous month or ~30 days.
- [~] **B-06** MUST scheduled backup runs **after** a successful sync, never before.
- [~] **B-07** MUST Backup Now works even when weekly/monthly is disabled.
- [~] **B-08** MUST backup paths include device name:
  ```text
  backups/weekly/notes-backup-weekly-<date>-device-<name>.zip
  backups/monthly/notes-backup-monthly-<yyyy-mm>-device-<name>.zip
  backups/manual/notes-backup-manual-<iso>-device-<name>.zip
  ```
- [~] **B-09** MUST zip contents: `backup.json`, `notes/`, `lists/`, `images/`, `tombstones/`.
- [~] **B-10** MUST `backup.json` = `backup_version, created_at, created_by_device_id, app_version, item_count, image_count`.
- [~] **B-11** MUST backup includes active + archived + trash items, checklist checked states, colors, images, **and tombstones** (so a restore cannot resurrect deletions).
- [~] **B-12** MUST update `last_backup_at` / `last_backup_status` after each attempt.
- [~] **B-13** MUST retention = manual only in v1; warn that image-heavy backups grow and that deleting a backup does not purge Git history.
- [ ] **B-14** LATER keep-last-N retention policy.
- [~] **B-15** MUST optional backup encryption (DEC-5), **off by default**:
  ```text
  PBKDF2-HMAC-SHA256, 200000 iterations, 16-byte random salt
  AES-256-GCM, 12-byte random nonce
  file layout: "NNBK1" | salt | nonce | ciphertext | tag
  filename: <name>.zip.enc
  ```
- [~] **B-16** MUST backup passphrase stored in `flutter_secure_storage`, never in SQLite.
- [~] **B-17** MUST warnings shown: "If you lose this passphrase, the backup cannot be recovered." and "Encryption applies to backups only. Synced notes are stored as plain text."
- [~] **B-18** GAP Restore-from-backup UI is **not** in v1 (docs never specify it). Backups are recovery artifacts; document manual restore. Flag if you disagree.

---

## 15. Export / Download — `E`

- [~] **E-01** MUST select a single item or multiple items for export.
- [~] **E-02** MUST selection: mobile long-press → selection mode → tap more cards → count in top bar; desktop checkbox or Ctrl/Cmd-click → context toolbar.
- [~] **E-03** MUST Export action appears only once items are selected.
- [~] **E-04** MUST exactly two formats: **PDF** and **TXT**. No MD/HTML/DOCX/JSON anywhere in the UI.
- [~] **E-05** MUST single item → one `.pdf` or one `.txt`, named `Title - YYYY-MM-DD.ext`, with unsafe filename characters sanitized.
- [~] **E-06** MUST multiple items → one `.zip` containing the individual files plus an `images/` folder.
- [~] **E-07** MUST PDF includes title, created date, updated date, images, and body or checklist items; optional color indicator and archive/trash status.
- [~] **E-08** MUST checklist PDF uses `☐` / `☑` marks.
- [~] **E-09** MUST PDF generated fully locally (`pdf` + `printing`).
- [~] **E-10** MUST TXT note format = title, blank line, body.
- [~] **E-11** MUST TXT checklist format uses `[ ]` / `[x]` marks.
- [ ] **E-12** LATER "export checklist without checkbox marks" setting; merge-all-into-one-PDF.
- [~] **E-13** MUST destination: Windows Save As dialog; Android share sheet or Downloads via system picker.
- [~] **E-14** MUST export works **fully offline** from local data.

---

## 16. Responsive Shell & Navigation — `U`

- [~] **U-01** MUST breakpoints: compact <600dp · medium 600–1024dp · expanded >1024dp.
- [~] **U-02** MUST progressive disclosure — primary actions visible, secondary in menus/sheets, rare in Settings.
- [~] **U-03** MUST desktop: left sidebar/NavigationRail (Home, Archive, Trash, Settings) + top bar (search, filters, view mode, sync, new, more) + card grid.
- [~] **U-04** MUST desktop toolbar order: `Search | All/Notes/Lists | View Mode | Sync | New | More`.
- [~] **U-05** MUST desktop card hover actions: color, archive, trash, more.
- [~] **U-06** MUST desktop multi-select toolbar: selected count, Export, Archive, Trash, Color.
- [ ] **U-07** LATER Ctrl+K command palette and full keyboard shortcuts.
- [~] **U-08** MUST mobile: top bar `Search | View icon | Sync icon | ⋮`, filter chips All/Notes/Lists, card list, bottom bar `Home | Archive | Trash | +`. No overlay FAB.
- [~] **U-09** MUST the trailing `+` on the mobile bottom bar opens a bottom sheet with **New Note** / **New List** (never two separate create buttons, never a fourth selected tab). Desktop keeps **New** in the top bar.
- [~] **U-10** MUST mobile Archive/Trash/Settings reachable from drawer or ⋮, Home stays primary.
- [~] **U-11** MUST card view modes Grid/Masonry (default), List, Compact — applied to Home, Archive, Trash, and search results.
- [~] **U-12** MUST card view mode saved in `settings.card_view_mode`, per-device, not synced.
- [~] **U-13** MUST **only one** view-mode icon on mobile, opening a bottom sheet with the three choices.
- [~] **U-14** MUST card content: title, first lines, first image thumbnail, checklist preview with `+N more`, color background, optional updated time.
- [~] **U-15** MUST mobile card gestures: tap = open View Mode; long-press = selection mode; ⋮ = Color/Archive/Trash/Export.
- [~] **U-16** MUST no swipe-to-trash in v1. Swipe-to-archive with Undo is LATER.
- [~] **U-17** MUST desktop open item = focused full page or large dialog; mobile = full-screen page.
- [~] **U-18** MUST item top bar (desktop): Back · Title · checklist checkbox toggle (checklist View Mode only) · View/Edit toggle · Color · Insert image (Edit Mode) · Copy All (View Mode) · More.
- [~] **U-19** MUST mobile View Mode bar = `Back | Title | Edit | ⋮`; Edit Mode bar = `Back | Save/View | ⋮`.
- [~] **U-20** MUST mobile ⋮ contains Copy All, Color, Archive, Move to Trash, Export, Insert image (Edit Mode only).
- [~] **U-21** MUST Settings holds token setup, backup settings, Backup Now, Disconnect — never on the home screen.
- [~] **U-22** MUST sync shown as a small cloud icon + last-synced tooltip; backup never on the home screen.
- [~] **U-23** MUST Material 3, soft rounded cards, pastel note colors, light + dark mode, subtle shadows, smooth transitions, good empty states.
- [~] **U-24** GAP Empty states needed for: no notes yet, empty archive, empty trash, no search results, sync not configured.
- [ ] **U-25** LATER checklist detail density (normal/compact).

---

## 17. Icon-First & Accessibility — `A`

- [~] **A-01** MUST actions are icon buttons; avoid text labels on action buttons.
- [~] **A-02** MUST icon map: new `+` · search · grid/list/compact · checkbox/list toggle · cloud-sync · cloud-upload backup · pencil edit · eye/check view · copy · copy-all · palette · image · archive-box · restore · trash · delete-forever warning · download export · gear settings · ⋮ more.
- [~] **A-03** MUST **every** icon-only button has a `Tooltip` and a `Semantics` label.
- [~] **A-04** MUST desktop hover shows tooltip; mobile long-press shows hint; screen readers read the label.
- [~] **A-05** MUST Settings pages keep readable text labels (clarity beats minimalism there).
- [~] **A-06** MUST dangerous actions get warning icon + confirmation dialog + explanation.
- [~] **A-07** GAP Minimum tap target 48×48 dp on mobile; visible focus indicators on desktop.

---

## 18. Settings — `SET`

- [~] **SET-01** MUST Appearance > Note/List Font Size: `A−  <size>  A+` or slider; options Small/Default/Large/Extra Large → scale 0.90 / 1.00 / 1.15 / 1.30 (14/16/18/20–22 px).
- [~] **SET-02** MUST font size affects **only** note/checklist content in View and Edit Mode.
- [~] **SET-03** MUST font size must **not** affect app bar, sidebar, settings labels, card icons, dialogs, system nav.
- [~] **SET-04** MUST applies immediately without restart; saved as `settings.content_font_scale`.
- [ ] **SET-05** LATER export/PDF font size follows the setting.
- [~] **SET-06** MUST Editor/Reading > Clickable URLs On/Off, saved as `settings.clickable_urls_enabled`, default **On**.
- [~] **SET-07** MUST URLs On → detected, styled as links, open in browser from View Mode.
- [~] **SET-08** MUST URLs Off → plain text, no navigation, still selectable and copyable.
- [~] **SET-09** MUST applies to both notes and checklists.
- [~] **SET-10** MUST Edit Mode never opens links, in either setting.
- [~] **SET-11** MUST in checklist View Mode, checkbox tap area and URL tap area are separate.
- [~] **SET-12** MUST support `http://` and `https://` in v1; confirm before opening unusual schemes. `mailto:`/`tel:` LATER.
- [~] **SET-13** MUST Settings sections: Appearance (theme, font size, card view) · Editor/Reading (URLs) · Sync · Backup · About.
- [~] **SET-14** GAP Theme mode selector: System / Light / Dark, local-only.

---

## 19. Build & Release — `BLD`

- [~] **BLD-01** MUST `flutter build windows` produces a runnable NoteNest.
- [~] **BLD-02** MUST `flutter build apk` (and `appbundle`) produces a runnable NoteNest.
- [~] **BLD-03** MUST Android: no unnecessary permissions; use scoped storage / SAF for export; camera permission only if capture is added (it is LATER).
- [~] **BLD-04** MUST Windows: local DB and images under the user's app-data directory, not next to the .exe.
- [~] **BLD-05** MUST `flutter analyze` clean; `dart format` applied.
- [~] **BLD-06** GAP Version stamp `1.0.0+1` surfaced in Settings > About and written into `backup.json`.

---

## 20. Manual QA Script — `QA`

Run this end-to-end before calling v1 done.

- [ ] **QA-01** Airplane mode: create, edit, view, color, pin, archive, trash, export — everything works offline.
- [ ] **QA-02** Create checklist with 5 lines, check 2, reorder lines in Edit Mode → the same two items are still checked.
- [ ] **QA-03** Edit one checked line's text → it becomes unchecked; others unaffected.
- [ ] **QA-04** Duplicate lines: `Milk, Milk` with one checked behaves per M-06.
- [ ] **QA-05** Toggle checkboxes off and on → checked states survive.
- [ ] **QA-06** Copy All on a note and on a checklist, on both platforms.
- [ ] **QA-07** Try to attach a `.mp4` and a `.pdf` → both rejected with a clear message.
- [ ] **QA-08** Archive → Trash → Restore lands back in **Archive**, not Home.
- [ ] **QA-09** Home → Trash → Restore lands back in **Home**.
- [ ] **QA-10** Empty Trash → confirmation → items gone → tombstones exist locally.
- [ ] **QA-11** Two devices: delete on A, sync A, sync B → item does not come back on B, ever, across repeated syncs.
- [ ] **QA-12** Two devices: delete on A; B edits the same item offline; B syncs → original stays deleted, a new-ID recovered conflict copy appears.
- [ ] **QA-13** Edit the same item on both devices → conflict copy created, neither version lost.
- [ ] **QA-14** Pin on A, sync both → pinned on B and sorted to the top.
- [ ] **QA-15** Open an item on B → A's ordering does not change after sync.
- [ ] **QA-16** Point sync at a **public** repo → refused with the private-repo error.
- [ ] **QA-17** Wrong token / wrong repo / wrong branch / offline → four distinct, clear errors.
- [ ] **QA-18** Disable Sync then re-enable → no token re-entry needed. Disconnect → token gone, notes intact.
- [ ] **QA-19** Backup Now → zip appears under `backups/manual/`, contains tombstones.
- [ ] **QA-20** Enable backup encryption → uploaded file is `.zip.enc` and is not readable as a zip.
- [ ] **QA-21** Export one item as PDF and as TXT; export three items → single zip with both formats.
- [ ] **QA-22** Font size Extra Large → note text grows, app bar and settings text do not.
- [ ] **QA-23** Clickable URLs Off → link is plain text, still copyable; On → opens browser.
- [ ] **QA-24** Every icon button shows a tooltip on desktop hover and reads correctly with TalkBack.
- [ ] **QA-25** Light and dark mode across all ten note colors.
- [ ] **QA-26** Resize desktop window from wide to narrow → layout adapts without overflow errors.

---

## 21. Build Order (do not reorder)

```text
Phase 1  Shell        P-01..P-09, U-01..U-03, U-08, U-23, theme, empty states
Phase 2  Data         D-01..D-10, entry repository, ULID ids
Phase 3  Local CRUD   N-01..N-11, K-01..K-10, M-01..M-08, COL-01..COL-06
Phase 4  Organize     T-01..T-17, S-01..S-14, U-11..U-16
Phase 5  Content      IMG-01..IMG-13, CP-01..CP-08, SET-01..SET-14
Phase 6  Export       E-01..E-14
Phase 7  Sync setup   SEC-01..SEC-17
Phase 8  Sync engine  X-01..X-16, G-01..G-18     <- hardest, most tests
Phase 9  Backup       B-01..B-18
Phase 10 Polish       A-01..A-07, BLD-01..BLD-06, QA-01..QA-26
```

Rule from the plan, restated: **do not start with sync.** The offline app must be excellent first.

---

## 22. Gaps I Filled (review these)

These were not specified in either document. I chose a sensible default so the build cannot stall. Override any of them by editing this file.

| ID | Gap | Default chosen |
|----|-----|----------------|
| P-07 | Device identity | ULID device_id + human device name, generated on first launch |
| P-08 | ID scheme | ULID everywhere |
| P-09 | Time storage | UTC ISO-8601 stored, local time displayed |
| N-07 | Autosave timing | 800 ms debounce + save on mode switch / back / app pause |
| N-11 | Empty titles | allowed, card falls back to first body line |
| S-13/14 | Search scope | title + body (covers checklist lines), 250 ms debounce, per-screen |
| COL-06 | Color in dark mode | each color needs a dark variant with contrast check |
| IMG-13 | Image removal | soft-delete then purge local file after remote delete succeeds |
| G-17 | Concurrent syncs | single-flight lock, cancellable |
| G-18 | Large repos | page directory listings above 1000 files |
| B-18 | Restore from backup | **not built in v1** — flag if you want it |
| U-24 | Empty states | five specific states enumerated |
| A-07 | Touch targets | 48×48 dp minimum, visible desktop focus rings |
| SET-14 | Theme selector | System / Light / Dark, local-only |
| BLD-06 | Versioning | `1.0.0+1`, shown in About and embedded in backup.json |

---

## 23. Traceability

Every numbered requirement above maps back to a section of the source documents:

```text
P    -> Final Recommended Stack, Recommended App Structure, Dev Environment
D    -> Local Database Recommendation, Recommended Internal Storage for Checklists
N    -> Product Design, Note Behavior, Checklist Behavior, View/Edit Mode Rule
K    -> Checklist Checkbox Visibility Toggle, Checklist Detail View Options
M    -> Checklist Checked-State Preservation (DECIDED, text-based)
CP   -> Copy Text Function in View Mode, Copy Text on Mobile View Mode
IMG  -> Image Insert Function, Image Insert UI, Image Delete Protection
COL  -> Color Option, Color Picker UI
S    -> Pinning and Sort Order Sync, Edited Items on Top, Last Viewed, Sort/View Options
T    -> Archive and Trash Logic and all its subsections
X    -> Critical Anti-Resurrection Delete Strategy and all its subsections
G    -> GitHub Sync Design, Sync Method, Conflict handling, Manual Sync Button
SEC  -> GitHub Authentication, Sync Activation, Token Storage/Replacement, Security Notes,
        Encryption Decision
B    -> GitHub Backup Settings and all its subsections, Encryption Decision Rule 4
E    -> Download / Export Notes and Lists and all its subsections
U    -> Responsive Interface Plan and all its subsections
A    -> Icon-First Button and Action Design
SET  -> Content Font Size Setting, URL Clickable Link Toggle
BLD  -> Goal (platform scope), Development Environment, Best Starting Path
```

Nothing in the two source documents is unrepresented here.

---

## 24. Later additions (session PIN lock + polish)

Added after v1, by request. Device-local only.

- [~] **PIN-01** MUST Settings > Privacy: set / change / remove a 4-digit PIN. Hash stored in `flutter_secure_storage`, never synced.
- [~] **PIN-02** MUST lock target: Notes only / Lists only / Both. Archive and Trash are never locked.
- [~] **PIN-03** MUST Home All hides locked types. Tapping Notes or Lists asks for the PIN. Both locked → PIN on app open.
- [~] **PIN-04** MUST auto-lock after 1 / 5 / 15 minutes. Closing the app locks at once. A phone left in the background stays unlocked until the timer ends.
- [~] **PIN-05** MUST auto-lock counts from the **last in-app activity** (tap, drag, scroll, physical key press, or editor typing), not from the moment of unlock, so it never fires mid-edit. Activity while locked never unlocks; returning from the background after the deadline still locks (PIN-04 wins over PIN-05).
- [~] **G-13b** MUST the top sync icon spins while a sync is running.
- [~] **AWK-01** MUST Android View Mode has a keep-screen-on toggle. Off when leaving the item or switching to Edit. Not shown on Windows.

## 25. v1.2 polish: motion, Material You, undo safety

Added after v1.1, by request. All device-local.

- [~] **MOT-01** MUST opening a card flies it into the item screen (shared-element Hero) and back on pop; skipped when the OS reports reduced motion.
- [~] **MOT-02** MUST switching Grid / List / Compact / Rows cross-fades instead of snapping; instant for reduced motion.
- [~] **MOT-03** MUST card colour and item background colour changes animate (~250 ms) instead of snapping.
- [~] **THM-01** SHOULD optional Material You wallpaper colours (Android 12+ via `dynamic_color`); opt-in in Appearance; other platforms and opt-out keep the built-in palette.
- [~] **THM-02** MUST optional true-black dark theme for AMOLED panels; dark theme only, light theme never affected.
- [~] **UND-01** MUST undo/redo controls in Edit Mode, backed by the platform undo stack so the IME keyboard and Ctrl+Z agree with the buttons.
- [~] **UND-02** MUST pin / colour / archive / trash / restore — single-entry and multi-select — confirm with a 5-second Undo snackbar that reverts to the previous value through the normal repository calls.
