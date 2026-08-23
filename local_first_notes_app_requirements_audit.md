# NoteNest — Local-First Notes App Requirements Audit

## Project Name

**NoteNest**

Meaning:

```text
Note = notes and lists
Nest = safe local home for data on each device
```

Recommended identifiers:

```text
Display name: NoteNest
Flutter project name: notenest
Suggested package id: com.yourname.notenest
Suggested GitHub repo name: notenest
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

Supported target platforms:

```text
Windows
macOS
Linux
Android
```

Recommended first development targets:

```text
Windows + Android first
macOS/Linux later
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

Formats included:

```text
PDF
Plain text .txt
Markdown .md
```

Note:

```text
The third format was assumed as Markdown because the user mentioned 3 formats but explicitly named PDF and text only.
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

### Checklist View Toggle Rule

```text
Only checklist/list items show the checkbox visibility toggle in View Mode.
Normal notes do not show this toggle.
```

---

## Further Changes Recommended Before Coding

No major missing function was found.

However, these small decisions should be finalized before actual coding starts.

### Decision 1: App Name — Completed

Chosen project name:

```text
NoteNest
```

Use this for:

```text
Flutter project name: notenest
Package/app display name: NoteNest
Window title: NoteNest
Android app name: NoteNest
Suggested GitHub repo name: notenest
```

Suggested package id placeholder:

```text
com.yourname.notenest
```

Replace `yourname` later with your preferred developer/company identifier.

---

### Decision 2: Third Export Format Confirmation

Current plan uses:

```text
PDF
TXT
Markdown
```

Please confirm whether Markdown `.md` is acceptable as the third format.

Alternative third format could be:

```text
HTML
DOCX
JSON
```

Recommended: Markdown.

---

### Decision 3: First Build Target

Recommended first targets:

```text
Windows desktop
Android mobile
```

Reason:

```text
This proves both PC and mobile behavior early.
```

macOS and Linux can be built later from the same Flutter codebase.

---

### Decision 4: Checklist Checked-State Preservation

Because Edit Mode is plain multiline text, the app must decide how checked states stay attached to lines.

Recommended MVP:

```text
Preserve checked state by line position.
```

Example:

```text
Line 1 checked state stays with line 1.
Line 2 checked state stays with line 2.
```

Known limitation:

```text
If user heavily reorders lines in Edit Mode, checked states may not always follow the exact item perfectly.
```

Better later:

```text
Smarter line matching by text + position.
```

Recommended for MVP:

```text
Start with line position.
Improve later if needed.
```

---

### Decision 5: Encryption

Current plan says encryption is a future feature.

If notes are sensitive, encryption should be added before serious GitHub use.

MVP recommendation:

```text
Start without encryption if this is personal/non-sensitive.
Add encryption later.
```

---

## Final Audit Conclusion

The plan is large, but it is complete enough to start development.

Recommended next step:

```text
Do not add more features now.
Freeze Version 1 scope.
Start building MVP in Flutter.
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
