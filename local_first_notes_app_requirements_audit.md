# NoteNest — Local-First Notes App Requirements Audit

## Project Name

**NoteNest**

Meaning:

```text
Note = notes and lists
Nest = safe local home for data on each device
```

Final identifiers (locked):

```text
Display name: NoteNest
Flutter project name: notenest
Package id: com.notenest.notenest
GitHub repo name: NoteNest
```

---

## Audit Result

The main plan file was checked:

```text
local_first_notes_app_plan.md
```

Current size:

```text
over 3200 lines
```

Conclusion:

```text
All major functions discussed so far are included in the plan.
```

Because the plan is now large, this audit/checklist file should be used as the compact implementation reference while coding.

---

## Confirmed Core Build Direction

```text
Project/app name: NoteNest
App type: Desktop + mobile local-first notes app
Style: Google Keep-inspired, but with custom logic
Framework: Flutter
Language: Dart
Database: SQLite using Drift
Sync target: GitHub private repository
Auth: Fine-grained GitHub Personal Access Token
Token storage: flutter_secure_storage
Offline support: Full local-first behavior
```

Version 1 target platforms (locked):

```text
Windows
Android
```

Out of scope for Version 1:

```text
macOS
Linux
```

---

## Feature Checklist

### 1. Notes and Lists

Included in plan: Yes

Requirements:

```text
Two main content groups:
  1. Notes
  2. Lists / Checklists
```

Notes:

```text
Title
Markdown/text body
Images only
No video or non-image file attachments
Color
View Mode
Edit Mode
```

Lists:

```text
Title
Plain multiline text in Edit Mode
Checkboxes before each line in View Mode when checkbox toggle is On
Plain text lines in View Mode when checkbox toggle is Off
Images only
No video or non-image file attachments
Color
View Mode
Edit Mode
```

Important checklist rule:

```text
Edit Mode behaves like a normal multiline note.
No separate add/delete item buttons.
Each line becomes a checkbox item in View Mode when the checklist checkbox toggle is On.
```

---

### 2. View Mode / Edit Mode

Included in plan: Yes

Requirements:

```text
Saved notes/lists open in View Mode by default.
User toggles to Edit Mode to edit content.
```

Notes:

```text
View Mode = read/copy only
Edit Mode = editable text
```

Lists:

```text
View Mode with checkbox toggle On = check/uncheck + copy text
View Mode with checkbox toggle Off = plain readable/copyable text
Edit Mode = edit lines as plain multiline text
```

Checklist checkbox visibility toggle:

```text
Available only for Lists/Checklists, not normal Notes
Visible in checklist View Mode
On = show checkboxes before each line
Off = hide checkboxes and show plain lines
Checked states are preserved while hidden
Recommended field: entries.checkboxes_visible_in_view
Checked state is matched by line TEXT, never by line position
```

---

### 3. Copy Text in View Mode

Included in plan: Yes

Requirements:

```text
Desktop text selection
Ctrl+C / Cmd+C
Right-click Copy
Mobile long-press selection
Copy All option
```

Applies to:

```text
Notes
Lists
```

---

### 4. Images

Included in plan: Yes

Requirements:

```text
Both notes and lists support image insertion only.
No video upload is allowed.
No PDF/document/non-image file attachment upload is allowed.
Images are stored locally first.
Images sync to GitHub later.
Images can show in View Mode and card preview.
```

Recommended MVP approach:

```text
Entry-level images first.
Inline Markdown images later.
Allowed MVP image types: JPG/JPEG, PNG, WebP.
No videos or generic file attachments.
```

---

### 5. Colors Like Google Keep

Included in plan: Yes

Requirements:

```text
Each note/list has its own color.
Color appears on cards and open item screens.
Color syncs across devices.
```

---

### 6. Pinning and Sort Order

Included in plan: Yes

Requirements:

```text
User can pin/unpin notes and lists.
Pinned status syncs across devices.
Pinned items appear above normal items.
Edited/updated items move to the top after sync.
```

Recommended sync behavior:

```text
Pin on PC -> synced to mobile
Unpin on mobile -> synced to PC
Edit on PC -> updated_at syncs -> item moves near top on mobile
Edit on mobile -> updated_at syncs -> item moves near top on PC
```

Recommended fields:

```text
is_pinned
pinned_at
pin_order, optional later
updated_at
content_updated_at
metadata_updated_at
```

Important recommendation:

```text
Last viewed/opened time should be local-only by default.
Do not sync last_viewed_at in MVP.
```

Reason:

```text
Opening a note on mobile should not unexpectedly reorder PC.
Viewing/opening creates too much unnecessary GitHub sync noise.
```

Recommended local field:

```text
last_viewed_at_local
```

---

### 7. Archive and Trash

Included in plan: Yes

Requirements:

```text
Note/list to Archive
Restore from Archive
Note/list to Trash
Restore from Trash
Archive to Trash
Trash to Archive
Empty Trash
Delete Forever from Trash
```

Recommended state model:

```text
entries.location = active / archive / trash / deleted
```

Important rule:

```text
Item cannot be both archived and trashed at the same time.
```

---

### 8. Anti-Resurrection Delete Protection

Included in plan: Yes, with heavy focus

Problem handled:

```text
Delete on one device, old offline device later syncs and brings it back.
```

Solution included:

```text
Tombstones
Fetch tombstones before pushing notes
Tombstone beats note file
Never upload original deleted ID again
Offline edits become recovered conflict copy with new ID
Keep tombstones forever in MVP
Use GitHub SHA/commit checking
```

This is one of the most important implementation rules.

---

### 9. GitHub Sync Activation

Included in plan: Yes

Requirements:

```text
User pastes GitHub Personal Access Token one time.
App tests connection.
Token is securely preserved.
Sync becomes enabled.
Manual Sync button becomes active.
```

Settings include:

```text
GitHub Sync On/Off
Owner/user
Repository name
Branch name
Token input
Test Connection
Save and Enable Sync
Disconnect GitHub Sync
```

---

### 10. Backup to GitHub

Included in plan: Yes

Requirements:

```text
Settings option for backup
Enable/disable backup
Weekly backup
Monthly backup
Manual Backup Now
Backup files saved to GitHub
```

Recommended backup format:

```text
.zip snapshot files
```

Recommended backup folder:

```text
backups/weekly/
backups/monthly/
backups/manual/
```

Backup includes:

```text
Active items
Archived items
Trash items
Checklist states
Colors
Images
Tombstones
```

---

### 11. Download / Export

Included in plan: Yes

Requirements:

```text
User can select single note/list.
User can select multiple notes/lists.
User can export/download.
```

Formats included (locked):

```text
PDF
Plain text .txt
```

Rule:

```text
Exactly two export formats. No Markdown, HTML, DOCX, or JSON export.
Markdown remains internal only: note body storage and GitHub sync files.
```

---

### 12. Responsive Interface

Included in plan: Yes

Requirements:

```text
Nice/stunning UI for PC and mobile.
Desktop uses more space.
Mobile stays clean and compact.
```

Desktop:

```text
Sidebar
Search
All / Notes / Lists filters
Card grid/masonry view
List view and compact view option
Hover actions
Multi-select toolbar
```

Mobile:

```text
Search top bar
All / Notes / Lists filter chips
Card list/grid/compact view option
Floating + button
Bottom sheet for New Note / New List
Full-screen item page
Three-dot menu for secondary actions
One view-mode icon for Grid/List/Compact on mobile
```

---

### 13. Icon-Based UI

Included in plan: Yes

Requirements:

```text
Buttons and clickable actions should be icon-first, not text-heavy.
Meaningful icons should be used.
```

Important accessibility rule:

```text
Icon-only buttons must still have tooltip and screen-reader labels.
View options should use meaningful icons: grid, list, compact-density, checkbox/list toggle.
```

---

### 14. Font Size Setting for Note/List Content

Included in plan: Yes

Requirements:

```text
Settings option to increase/decrease note/list content font size.
Only note/list content changes, not full interface.
```

Applies to:

```text
Note View Mode
Note Edit Mode
Checklist View Mode
Checklist Edit Mode
```

---

### 15. URL Clickable Toggle

Included in plan: Yes

Requirements:

```text
Settings toggle for clickable URLs On/Off.
```

When On:

```text
URLs are clickable in View Mode.
```

When Off:

```text
URLs appear as plain text only.
User can still select/copy.
```

Applies to:

```text
Notes
Lists
```

---

## Required Implementation Guardrails

These rules must be followed while coding.

### Local-First Rule

```text
App must open and work without internet.
All edits save locally first.
GitHub is only sync/backup, not the live database.
```

### Delete Safety Rule

```text
Permanent delete always creates a tombstone.
Sync must pull tombstones before pushing notes.
Deleted original IDs must never be uploaded again.
```

### Token Security Rule

```text
Never hardcode token.
Never store token in SQLite/plain file.
Never log token.
Use flutter_secure_storage.
```

### Mobile UI Rule

```text
Do not show all features at once on mobile.
Use icon buttons, menus, bottom sheets, and contextual toolbars.
```

### Export Rule

```text
Export/download must work offline from local data.
```

### Image-Only Rule

```text
Only images are allowed inside notes/lists.
No video upload.
No PDF/document/generic file attachments.
```

### Checklist Checked-State Rule

```text
Checked state is matched by line text.
Same text keeps its checkmark, even if the line moved.
Any text change makes the line unchecked.
Never match by line position.
```

### Export Format Rule

```text
Exactly two export formats: PDF and TXT.
Markdown is internal storage/sync only, never an export option.
```

### Platform Scope Rule

```text
Version 1 builds Windows and Android only.
```

### Encryption Rule

```text
Sync is enabled only for a verified PRIVATE repository.
Note files sync as plain Markdown in v1.
Backup encryption is optional, off by default, AES-256-GCM with PBKDF2.
Backup passphrase lives in flutter_secure_storage, never in SQLite.
```

### Checklist View Toggle Rule

```text
Only checklist/list items show the checkbox visibility toggle in View Mode.
Normal notes do not show this toggle.
```

---

## Final Decisions — All Locked

All five open decisions are now answered. Nothing below is optional.

### Decision 1: App Name — LOCKED

```text
Display name: NoteNest
Flutter project name: notenest
Package id: com.notenest.notenest
Windows title: NoteNest
Android label: NoteNest
GitHub repo name: NoteNest
```

No `yourname` placeholder remains anywhere.

---

### Decision 2: Export Formats — LOCKED

```text
PDF
Plain text .txt
```

Only two. The Export menu must not show a third option.

```text
No Markdown export
No HTML export
No DOCX export
No JSON export
```

Markdown is still used internally for note bodies and for the one-file-per-note
GitHub sync format. That is storage, not an export feature.

Multi-item export still produces one .zip containing the chosen format files.

---

### Decision 3: Build Targets — LOCKED

```text
Version 1: Windows desktop + Android
```

```text
macOS: not in Version 1
Linux:  not in Version 1
```

Keep the code portable, but do not spend Version 1 time on macOS/Linux
packaging, file pickers, or testing.

---

### Decision 4: Checklist Checked-State Preservation — LOCKED (Text-Based)

Checked state follows the LINE TEXT, not the line position.

```text
Text unchanged            -> checkmark is kept
Text changed in any way   -> line becomes unchecked
Line moved, text same     -> checkmark is kept
New line                  -> unchecked
Deleted line              -> state discarded
```

Matching algorithm on save:

```text
1. Build a map from old items: normalized text -> queue of checked flags
2. Split the editor text into non-empty lines
3. For each new line in order:
     if the map still has an entry for that text -> take it, reuse checked
     else -> checked = false
4. Rewrite checklist_items in the new line order
```

Normalization:

```text
Trim ends
Collapse internal whitespace runs to one space
Case-sensitive
```

Duplicates are matched in order of appearance.

Explicitly rejected:

```text
Position/index-based matching
```

---

### Decision 5: Encryption — LOCKED (Easy + Good Option Chosen)

Version 1 does the cheap, high-value security work and skips the risky part.

Included in Version 1:

```text
Token only in flutter_secure_storage
Token never in SQLite, plain files, logs, exports, or backups
Test Connection must verify the repo is PRIVATE, and refuse to enable sync if public
Optional encrypted backup file, OFF by default
```

Encrypted backup scheme when enabled:

```text
Key derivation: PBKDF2-HMAC-SHA256, 200000 iterations, 16-byte random salt
Cipher:         AES-256-GCM, 12-byte random nonce
Output file:    notenest-backup-YYYY-MM-DD.zip.enc
Layout:         magic "NNBK1" | salt | nonce | ciphertext | tag
Passphrase:     stored in flutter_secure_storage, never in SQLite
```

Not included in Version 1:

```text
Encryption of synced note .md files
Encrypted local database (SQLCipher)
```

Reason: plain .md sync files stay readable on github.com, stay recoverable
without the app, and keep the tombstone/anti-resurrection logic simple.
Per-note encryption adds key management and permanent data-loss risk.

Mandatory UI warnings:

```text
"If you lose this passphrase, the backup cannot be recovered."
"Encryption applies to backups only. Synced notes are stored as plain text."
"Deleted content may remain in GitHub commit history."
"Do not store passwords or highly sensitive data in NoteNest v1."
```

---

## Final Audit Conclusion

The plan is large, but it is complete enough to start development.

All five open decisions are now answered and locked.

Recommended next step:

```text
Do not add more features now.
Version 1 scope is frozen.
Scaffold the Flutter project: notenest / com.notenest.notenest
Build Windows + Android, local-only first, sync after.
```

MVP should focus on:

```text
Local database
Notes
Lists
View/Edit mode
Images
Colors
Archive/Trash
Safe delete tombstones
Manual GitHub sync
Settings
Responsive UI
Export
Backup
```
