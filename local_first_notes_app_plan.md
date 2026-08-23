# NoteNest — Local-First Notes App Build Plan

## Project Name

**NoteNest**

Meaning:

```text
Note = notes and lists
Nest = safe local home for data on each device
```

Why this name fits:

```text
Short and memorable
Meaningful for a local-first notes app
Not too technical
Works for desktop and mobile
Suggests safety, organization, and personal storage
```

Recommended identifiers:

```text
Display name: NoteNest
Flutter project name: notenest
Suggested package id: com.yourname.notenest
Suggested GitHub repo name: notenest
```

---

## Goal

Build your own note-taking app that works on:

- Windows PC
- macOS
- Linux
- Android

Main requirement:

> The app must work fully offline first, store data locally on each device, and sync through GitHub only when internet is available.

GitHub should be used as a sync and backup target, **not** as the main database.

---

## Final Recommended Stack

```text
Project/app name: NoteNest
App framework: Flutter
Programming language: Dart
Local database: SQLite
Database library: Drift
Editor format: Markdown
Sync target: GitHub private repository
Authentication: Fine-grained GitHub Personal Access Token
Secure token storage: flutter_secure_storage
```

---

## Why Flutter?

Flutter is a cross-platform app framework from Google.

With one Flutter codebase, you can build apps for:

```text
Windows
macOS
Linux
Android
iOS
Web
```

For this project, the main targets are:

```text
Windows
macOS
Linux
Android
```

Flutter is also good for building a polished and modern interface. You can create a beautiful note-taking app with:

- Dark mode and light mode
- Desktop sidebar layout
- Mobile-friendly navigation
- Smooth animations
- Markdown editor
- Search
- Tags
- Beautiful note cards
- Responsive layout

---

## Important Point About One App on Many Devices

It is not one single install file for every platform.

It is:

```text
One source code project
Different builds for each platform
```

Example:

```text
Flutter source code
        |
        |-- Windows build: .exe / .msix
        |-- macOS build: .app / .dmg
        |-- Linux build: AppImage / .deb / .rpm
        |-- Android build: .apk / .aab
```

The app logic, UI design, local database, and sync system stay mostly the same.

---

## Local-First Architecture

Each device stores its own local data.

```text
Windows laptop  -> local SQLite database
Android phone   -> local SQLite database
Linux desktop   -> local SQLite database
MacBook         -> local SQLite database
```

GitHub connects them only for sync:

```text
Windows local DB  ---> GitHub private repo <--- Android local DB
Linux local DB    ---> GitHub private repo <--- macOS local DB
```

When offline:

```text
App opens normally
Notes can be created
Notes can be edited
Notes are saved locally
No internet required
```

When online:

```text
App checks GitHub
Pulls remote changes
Pushes local changes
Handles conflicts safely
```

---

## Local Database Recommendation

Use:

```text
SQLite + Drift
```

### Why Drift instead of sqflite?

`sqflite` is simple, but Drift is better for this project because the app needs sync management.

Drift gives:

- Typed database tables
- Cleaner database code
- Easier migrations
- Better structure for a larger app
- Reactive data updates
- Better maintainability

This app will need sync and state fields such as:

```text
id
title
body
location: active/archive/trash
previous_location_before_trash
color_key
created_at
updated_at
archived_at
trashed_at
permanently_deleted_at
local_changed
last_synced_at
last_remote_sha
last_local_hash
sync_status
```

Drift will make this easier to manage than plain sqflite.

---

## Note Format

Use Markdown for note content.

Example note body:

```markdown
# My Note

This is my note.

- task one
- task two
```

Why Markdown is good:

- Simple text format
- Easy to sync
- Easy to export
- Human-readable
- Compatible with tools like Obsidian, Logseq, and Joplin
- Long-term safe format

---

## Product Design: Notes and Lists

The app should feel like a simple Google Keep-style note app, but with two clear content groups:

```text
1. Notes
2. Lists / Checklists
```

The app should stay simple. Notes and lists are almost the same, except lists have checkbox behavior in View Mode.

---

### Home Screen Groups

Recommended home filters:

```text
All | Notes | Lists
```

Each saved item appears as a card, similar to Google Keep.

---

### Note Behavior

A normal note contains:

```text
Title
Body text / Markdown
Images only
No video or non-image file attachments
Color
```

When a note is opened:

```text
Default mode: View Mode
```

In View Mode:

```text
User reads the note
Markdown is rendered nicely
Text is not editable
```

In Edit Mode:

```text
User can edit title
User can edit body
App autosaves locally
```

---

### Checklist Behavior

A checklist/list contains:

```text
Title
Body lines
Images only
No video or non-image file attachments
Color
```

Each non-empty line is treated as one checklist item.

Example in Edit Mode:

```text
Shopping List

Rice
Milk
Tea
Sugar
```

No separate item delete buttons are needed.

In Edit Mode, the checklist should behave like a normal multiline note editor:

```text
Add item      = create a new line
Delete item   = delete the line
Edit item     = edit the line text
Reorder item  = cut/paste or move the line
```

In View Mode, the same content appears with checkboxes before each line:

```text
☐ Rice
☑ Milk
☐ Tea
☐ Sugar
```

In Checklist View Mode:

```text
User can check/uncheck items
User cannot edit item text
User cannot add new item
User cannot delete item
User cannot reorder items
```

This keeps the UI very simple.

---

### Checklist Checkbox Visibility Toggle

Important requirement:

```text
Only List/Checklist items have a checkbox visibility toggle in View Mode.
Normal Notes do not show this toggle.
```

In checklist View Mode, the user can toggle whether checkboxes are visible.

Recommended states:

```text
Checkboxes On  = show checkbox before every non-empty line
Checkboxes Off = show the same lines as plain readable text
```

Example with checkboxes On:

```text
☐ Rice
☑ Milk
☐ Tea
☐ Sugar
```

Example with checkboxes Off:

```text
Rice
Milk
Tea
Sugar
```

Behavior:

```text
The toggle is visible only for checklist/list items.
The toggle is visible only in View Mode.
The toggle does not convert the item into a normal note.
Checked/unchecked states are preserved even when checkboxes are hidden.
When checkboxes are hidden, text remains selectable and copyable.
```

Recommended default:

```text
Checkboxes On for checklist/list items
```

Recommended saved setting:

```text
entries.checkboxes_visible_in_view
```

This should be saved per checklist/list, because one list may be used as a task checklist and another list may be used as a plain readable list.

Recommended icon:

```text
Checked-box icon = checkboxes on
Plain-lines/list icon = checkboxes off
```

Recommended placement:

```text
Desktop checklist View Mode: top item toolbar, near View/Edit toggle
Mobile checklist View Mode: top bar beside Edit icon if space, otherwise first item in ⋮ menu
```

---

### View Mode / Edit Mode Rule

Every saved note or list opens in View Mode first.

```text
Open item -> View Mode
Tap/click Edit toggle -> Edit Mode
Tap/click View toggle -> View Mode
```

For notes:

```text
View Mode = read only, but text can be selected and copied
Edit Mode = editable
```

For checklists:

```text
View Mode = check/uncheck only when checkbox toggle is On; text can be selected and copied
View Mode with checkbox toggle Off = plain readable list text; no checkbox actions
Edit Mode = edit lines like normal text
```

---

### Copy Text Function in View Mode

View Mode must support copying text properly on desktop and mobile.

Recommended copy behavior:

```text
Desktop:
  User can select text with mouse
  Ctrl+C / Cmd+C works
  Right-click context menu has Copy
  Copy All button is available

Mobile:
  Long press text selection works
  Native copy menu works
  Copy All button is available
```

Recommended copy options:

```text
Copy selected text
Copy note/list body only
Copy title + body
```

For checklist/list copy, recommended plain text format:

```text
Rice
Milk
Tea
Sugar
```

Optional later format:

```text
[ ] Rice
[x] Milk
[ ] Tea
[ ] Sugar
```

The app should not block copy just because the content is in View Mode.

---

### Image Insert Function — Images Only

Both Notes and Lists must support image insertion.

Important rule:

```text
Only images are allowed.
No video upload.
No PDF/document/file attachment upload.
```

Recommended MVP behavior:

```text
User can insert one or more images into any note or list
Images show inside the note/list view
Images show on the note/list card preview if available
Images are stored locally first
Images sync to GitHub when internet is available
```

For the first version, images should be entry-level images, not complex inline editing.

Example:

```text
Note/List
  title
  images
  body text or checklist lines
```

This is simpler and more stable for desktop + mobile.

Later, inline images can be added for Markdown notes using:

```markdown
![image](image://image-id)
```

Recommended local image handling:

```text
Store original image file in local app images folder
Create smaller thumbnail for card preview
Save image metadata in SQLite
Sync image file to GitHub images folder
```

Recommended GitHub structure for images:

```text
my-notes/
  notes/
    note-id-1.md

  images/
    image-id-1.jpg
    image-id-2.png

  thumbnails/
    image-id-1.jpg
```

Recommended images table:

```text
entry_images
  id
  entry_id
  file_name
  local_path
  remote_path
  mime_type
  size_bytes
  width
  height
  created_at
  deleted_at
  local_changed
  sync_status
```

Important GitHub warning:

```text
Do not use GitHub for video or large file storage.
Only image files are allowed in NoteNest.
Compress images before sync if possible.
Avoid syncing very large images frequently.
```

---

### Color Option

Both Notes and Lists must support a separate color, similar to Google Keep.

Recommended behavior:

```text
Each note/list can have its own color
Color appears on card background
Color appears on open View/Edit screen
Color syncs across devices through GitHub
```

Recommended default colors:

```text
Default
Red
Orange
Yellow
Green
Teal
Blue
Purple
Pink
Brown/Gray
```

Recommended database field:

```text
entries.color_key
```

Example values:

```text
default
yellow
green
blue
purple
red
```

---

### Pinning and Sort Order Sync

Notes and lists should support pinning, similar to Google Keep.

Important sync rule:

```text
Pinned status must sync across devices.
```

Example:

```text
If user pins a note on PC, it should appear pinned on mobile after sync.
If user unpins a note on mobile, it should become unpinned on PC after sync.
```

Recommended pinned fields:

```text
entries.is_pinned
entries.pinned_at
entries.pin_order, optional later
```

Recommended behavior:

```text
Pinned items appear above normal items.
Pinned state is preserved when the item is archived or restored.
Trash screen can ignore pinned display, but the pinned value can remain stored.
```

---

#### Edited Items on Top

Edited notes/lists should move to the top according to the selected sort mode.

Recommended default sort:

```text
Pinned items first
Then unpinned items sorted by last edited/updated time, newest first
```

Recommended order:

```text
1. Pinned notes/lists
2. Recently edited notes/lists
3. Older notes/lists
```

This should sync across devices because edited time is part of note/list metadata.

Example:

```text
1. User edits a note on PC.
2. entries.updated_at changes.
3. PC syncs to GitHub.
4. Mobile syncs from GitHub.
5. Mobile shows that note near the top.
```

Recommended fields:

```text
entries.updated_at
entries.content_updated_at
entries.metadata_updated_at
```

Simple MVP rule:

```text
Use entries.updated_at for sorting by recently edited.
Sync updated_at through GitHub.
```

Later, if needed, separate sorting can use:

```text
content_updated_at  = title/body/checklist/image changes
metadata_updated_at = color/pin/archive/trash changes
```

---

#### Last Viewed / Last Opened Behavior

Important recommendation:

```text
Last viewed/opened time should be local-only by default.
Do not sync last_viewed_at between devices in MVP.
```

Reason:

```text
Opening a note on mobile should not unexpectedly reorder the note list on PC.
Opening notes would create many unnecessary GitHub sync changes.
It can cause noisy conflicts and pointless sync traffic.
```

Recommended field:

```text
entries.last_viewed_at_local
```

This field should stay only on the current device.

If user wants a Recently Viewed sort, it can exist as a local device option:

```text
Sort by Recently Viewed, local only
```

Optional future setting:

```text
Sync recently viewed across devices: On/Off
```

Recommended MVP:

```text
Pin status syncs.
Edited/updated order syncs.
Last viewed/opened order does not sync.
```

---

#### Sort/View Options

Recommended sort options:

```text
Recently edited, default
Created newest
Created oldest
Title A-Z
Recently viewed, local-only
```

Recommended placement:

```text
Desktop: top toolbar view/sort menu
Mobile: top bar view icon or ⋮ menu, opening a bottom sheet
```

Sort preference is a device UI preference.

Recommended rule:

```text
Sort mode can stay local per device.
Pinned status and updated_at metadata sync through GitHub.
```

---

### Archive and Trash Logic

Archive and Trash should be handled as item states, not as separate copies of notes.

Use one main state field:

```text
entries.location
```

Recommended location values:

```text
active    = normal home item
archive   = archived item
trash     = item moved to trash
deleted   = permanently deleted tombstone, internal sync state only
```

Important rule:

```text
An item should never be both archived and trashed at the same time.
```

The `location` field is the source of truth.

---

#### Home, Archive, and Trash Screens

Recommended navigation:

```text
Home
Archive
Trash
Settings
```

Home should show only:

```text
location = active
```

Archive should show only:

```text
location = archive
```

Trash should show only:

```text
location = trash
```

The existing filters can still work inside each screen:

```text
All | Notes | Lists
```

Example:

```text
Home > All
Home > Notes
Home > Lists

Archive > All
Archive > Notes
Archive > Lists

Trash > All
Trash > Notes
Trash > Lists
```

---

#### Archive Action

When user archives a note/list from Home:

```text
location = archive
archived_at = now
trashed_at = null
previous_location_before_trash = null
metadata_updated_at = now
local_changed = true
```

Result:

```text
Item disappears from Home
Item appears in Archive
Content is not deleted
Images are not deleted
Color is kept
Checklist checkbox states are kept
```

---

#### Restore from Archive

When user restores from Archive:

```text
location = active
trashed_at = null
previous_location_before_trash = null
metadata_updated_at = now
local_changed = true
```

Result:

```text
Item disappears from Archive
Item appears in Home
```

`archived_at` can be cleared or kept for history, but the UI should depend on `location`, not `archived_at`.

Recommended simple MVP choice:

```text
Clear archived_at when restored from Archive.
```

---

#### Move to Trash

Moving to Trash is a soft delete, not permanent deletion.

When user moves an item to Trash from Home:

```text
previous_location_before_trash = active
location = trash
trashed_at = now
metadata_updated_at = now
local_changed = true
```

When user moves an item to Trash from Archive:

```text
previous_location_before_trash = archive
location = trash
trashed_at = now
metadata_updated_at = now
local_changed = true
```

Result:

```text
Item disappears from Home/Archive
Item appears in Trash
Content is not deleted yet
Images are not deleted yet
Color is kept
Checklist checkbox states are kept
```

---

#### Restore from Trash

Recommended default behavior:

```text
Restore from Trash returns the item to where it came from.
```

If the item came from Home:

```text
previous_location_before_trash = active
Restore -> location = active
```

If the item came from Archive:

```text
previous_location_before_trash = archive
Restore -> location = archive
```

On restore:

```text
location = previous_location_before_trash or active
trashed_at = null
previous_location_before_trash = null
metadata_updated_at = now
local_changed = true
```

Recommended Trash item actions:

```text
Restore
Move to Home
Move to Archive
Delete forever
```

`Restore` uses the previous location. `Move to Home` and `Move to Archive` are explicit actions.

---

#### Archive to Trash

This is allowed.

When user moves archived item to Trash:

```text
previous_location_before_trash = archive
location = trash
trashed_at = now
metadata_updated_at = now
local_changed = true
```

Result:

```text
Item leaves Archive
Item appears in Trash
```

---

#### Trash to Archive

This is allowed as an explicit action.

When user chooses `Move to Archive` from Trash:

```text
location = archive
archived_at = now
trashed_at = null
previous_location_before_trash = null
metadata_updated_at = now
local_changed = true
```

Result:

```text
Item leaves Trash
Item appears in Archive
```

---

#### Empty Trash

Empty Trash means permanent deletion from the app.

Recommended behavior:

```text
User clicks Empty Trash
App shows confirmation dialog
User confirms
All trash items are marked permanently deleted
Local content and image files are removed or queued for removal
GitHub files are deleted on next sync
Tombstones are kept for sync safety
```

Do not immediately remove every database row without a tombstone.

For local-first GitHub sync, tombstones are important because they stop old offline devices from bringing deleted notes back.

Recommended permanent delete fields:

```text
location = deleted
permanently_deleted_at = now
content_deleted = true
local_changed = true
sync_status = pending_delete
```

Recommended tombstone data to keep:

```text
id
type
permanently_deleted_at
last_known_remote_path
last_known_image_ids
```

The full note body and image files can be deleted locally, but the tombstone metadata should remain until every device has had a chance to sync.

Recommended tombstone retention:

```text
Keep tombstones for at least 90 days
or keep them forever because they are small
```

---

#### Delete Forever Single Item

Recommended rule:

```text
Delete forever is available only inside Trash.
```

From Home or Archive, the delete action should mean:

```text
Move to Trash
```

Inside Trash, user can choose:

```text
Delete forever
```

This avoids accidental permanent deletion.

---

#### Auto Empty Trash

Optional later feature:

```text
Automatically delete trash items after 30 days
```

For the MVP, manual Empty Trash is enough.

Recommended MVP:

```text
No automatic empty trash
Only manual Empty Trash
```

---

#### GitHub Sync Warning for Permanent Delete

Because GitHub is based on Git history, deleting a note file from the latest version does not always erase old content from repository history.

Important privacy rule:

```text
Empty Trash removes items from the app and latest synced files,
but old content may still exist in GitHub commit history.
```

If notes may contain sensitive data, use client-side encryption before syncing to GitHub.

Recommended future feature:

```text
Encrypted GitHub sync using AES-256-GCM
```

---

#### Critical Anti-Resurrection Delete Strategy

This is one of the most important parts of the whole app.

Problem to avoid:

```text
1. Phone deletes a note and syncs to GitHub.
2. Laptop was offline and still has the old note locally.
3. Laptop comes online later.
4. Bad sync logic sees the note missing on GitHub and uploads it again.
5. Deleted note comes back.
```

This must not happen.

The solution is:

```text
Use tombstones + pull tombstones before pushing + never blindly recreate missing remote files.
```

---

##### What is a Tombstone?

A tombstone is a small delete record that says:

```text
This note/list ID was permanently deleted.
Do not upload it again.
Do not recreate it from another offline device.
```

A tombstone does not need to keep the full note body.

Recommended tombstone file in GitHub:

```text
.tombstones/entries/note-id-1.json
```

Example tombstone:

```json
{
  "id": "note-id-1",
  "type": "note",
  "deleted_at": "2026-07-27T10:20:00Z",
  "deleted_by_device_id": "android-phone-abc123",
  "delete_revision_id": "01JZDELETEULID123",
  "last_known_note_path": "notes/note-id-1.md",
  "last_known_image_ids": ["image-id-1", "image-id-2"],
  "reason": "delete_forever"
}
```

Recommended local table:

```text
tombstones
  entry_id
  type
  deleted_at
  deleted_by_device_id
  delete_revision_id
  last_known_note_path
  last_known_image_ids
  synced
  remote_sha
```

---

##### Tombstone Rule

This rule is mandatory:

```text
If a tombstone exists for an entry ID, that original entry ID must never be uploaded again.
```

Even if the note file still exists locally on an old offline device, the tombstone wins.

If GitHub has both:

```text
notes/note-id-1.md
.tombstones/entries/note-id-1.json
```

then the app must treat the note as deleted.

Recommended rule:

```text
Tombstone beats note file.
```

---

##### Correct Sync Order

The sync engine must follow this order:

```text
1. Check internet.
2. Fetch remote tombstones from GitHub first.
3. Apply tombstones locally before uploading anything.
4. Fetch remote note/list changes.
5. Merge remote changes into local database.
6. Upload local tombstones/deletes.
7. Upload local non-deleted note/list changes.
```

Most important rule:

```text
Never push local notes before checking remote tombstones.
```

This single rule prevents most deleted-note resurrection bugs.

---

##### Delete Forever Flow

When user chooses Delete Forever or Empty Trash:

```text
1. Mark local entry as deleted.
2. Create local tombstone.
3. Remove local note body and image files, or queue them for cleanup.
4. On next sync, upload tombstone to GitHub first.
5. After tombstone exists remotely, delete the note file from GitHub latest branch.
6. Delete related image files from GitHub latest branch.
```

Important order:

```text
Upload tombstone first.
Delete note file second.
```

Reason:

```text
If the app crashes after uploading tombstone but before deleting the note file,
other devices still know the note is deleted because the tombstone exists.
```

If using GitHub Git Data API later, the best method is one atomic commit:

```text
Add tombstone file
Delete note file
Delete image files
Update branch
```

For MVP using GitHub Contents API, do it safely in this order:

```text
1. PUT tombstone file
2. DELETE note file
3. DELETE image files
4. If some delete step fails, retry later
```

---

##### Offline Device Comes Back Online

Scenario:

```text
Phone deletes note and syncs tombstone.
Laptop was offline and still has old note.
Laptop comes online later.
```

Correct laptop sync behavior:

```text
1. Laptop fetches tombstones first.
2. Laptop sees tombstone for note-id-1.
3. Laptop checks local note-id-1.
4. If local note has no unsynced edits, laptop marks it deleted locally.
5. Laptop does not upload note-id-1.
```

Result:

```text
Deleted note does not come back.
```

---

##### If Offline Device Edited the Note Before Seeing Delete

Scenario:

```text
Phone permanently deletes note and syncs tombstone.
Laptop was offline.
Laptop edits the same note while offline.
Laptop comes online later.
```

The app should not silently destroy the laptop edit, but it also must not resurrect the deleted original ID.

Recommended behavior:

```text
1. Apply tombstone to the original note ID.
2. Do not upload the original note ID.
3. Create a recovered conflict copy with a new note ID.
4. Mark the copy with sync_status = conflict_review.
5. Show it to the user as a recovered conflict, not as the original note.
```

Example recovered copy title:

```text
Recovered conflict - Shopping List - from Laptop - 2026-07-27
```

Important difference:

```text
Bad: Re-upload same deleted note ID.
Good: Create a clearly labeled new conflict copy only if unsynced edits exist.
```

This prevents unwanted resurrection while protecting real offline work.

---

##### Never Blindly Recreate Missing Remote Files

Bad sync rule:

```text
If local note exists and GitHub file is missing, upload local note.
```

This causes deleted notes to come back.

Correct sync rule:

```text
If local note exists and GitHub file is missing:
  1. Check tombstones first.
  2. If tombstone exists, delete local original.
  3. If no tombstone exists but local note was previously synced, treat as remote-delete conflict.
  4. Do not automatically recreate it without a safe decision.
```

Recommended remote-missing behavior:

```text
If local note was never synced before:
  Upload as new.

If local note was synced before and remote file is now missing:
  Check tombstone.
  If tombstone exists -> mark local deleted.
  If no tombstone -> show sync conflict or create tombstone depending on policy.
```

---

##### Use GitHub SHA / Commit Compare-And-Swap

When updating a note file through GitHub, do not overwrite blindly.

For GitHub Contents API:

```text
Keep last_remote_sha for every note file.
When updating, send the current remote sha.
If GitHub rejects because sha changed, pull remote first and merge.
```

For GitHub Git Data API:

```text
Update branch only if the branch head is still the commit you based your sync on.
If branch changed, pull and merge first.
```

This prevents this problem:

```text
Device A moves note to Trash.
Device B has old active copy.
Device B overwrites GitHub with active copy.
```

Mandatory rule:

```text
No force overwrite.
No force push.
No blind PUT without checking current remote state.
```

---

##### Tombstone Retention

Tombstones should not be deleted too quickly.

If a tombstone is removed too early, an old device that has been offline for a long time can bring the deleted note back.

Recommended MVP:

```text
Keep tombstones forever.
```

This is acceptable because tombstones are tiny JSON files.

Optional later improvement:

```text
Track registered devices and last successful sync time.
Remove a tombstone only after every known device has synced after the delete date.
```

Recommended device table:

```text
devices
  device_id
  device_name
  platform
  first_seen_at
  last_sync_at
```

But for the first version:

```text
Keep tombstones forever.
```

This is the safest choice.

---

##### Image Delete Protection

When a note/list is permanently deleted, its images must not come back either.

Recommended rule:

```text
An entry tombstone also blocks all images belonging to that entry.
```

If a device has old local images for a deleted entry:

```text
Do not upload those images.
Delete or quarantine them locally.
```

The tombstone should list image IDs when possible:

```json
"last_known_image_ids": ["image-id-1", "image-id-2"]
```

---

##### Final Anti-Resurrection Rules

These rules must be followed in code:

```text
1. Permanent delete always creates a tombstone.
2. Tombstone is synced before note file deletion.
3. Sync always pulls tombstones before pushing notes.
4. Tombstone wins over local note, remote note, and image files.
5. A deleted original ID is never uploaded again.
6. Old offline edits become a new conflict copy, not the same original ID.
7. Never recreate a missing GitHub file without checking tombstones.
8. Never overwrite GitHub blindly; use sha/commit checks.
9. Keep tombstones forever in MVP.
10. Empty Trash creates tombstones for every item being permanently deleted.
```

If these rules are implemented, deleted notes/lists will not keep coming back from other devices.

---

#### Sync Conflict Rule for Archive and Trash

Archive and Trash are metadata/location changes. They should sync like title/color changes.

Recommended MVP conflict rule:

```text
If only location changed on one device, apply the location change.
If content changed on one device and location changed on another, keep the content and apply the location if safe.
If permanent delete conflicts with unsynced content edits, do not destroy the edit. Create a conflict copy.
```

Conflict copy example:

```text
Original deleted note conflict - recovered from Android 2026-07-27
```

Safe principle:

```text
Soft actions can be synced normally.
Destructive actions must not silently delete unsynced edits.
```

---

### Recommended Internal Storage for Checklists

Even though the checklist UI is a plain multiline editor, internally it is still better to store checklist lines with individual checked states.

Recommended internal structure:

```text
entries table
  id
  type: note/checklist
  title
  body_markdown or body_text
  color_key
  is_pinned
  pinned_at
  pin_order, optional later
  location: active/archive/trash/deleted
  previous_location_before_trash
  created_at
  updated_at
  content_updated_at
  metadata_updated_at
  last_viewed_at_local, local-only and not synced
  archived_at
  trashed_at
  permanently_deleted_at
  sync fields

checklist_items table
  id
  entry_id
  text
  checked
  sort_order
  created_at
  updated_at
  deleted_at
```

The user does not see separate item controls. This table is only for the app's internal logic.

How it works:

```text
Edit Mode:
  App shows checklist item texts as plain lines.

Save:
  App splits text by lines and updates checklist_items.

View Mode:
  App renders every non-empty line as a checkbox item.
```

For the MVP, checkbox state can be preserved mostly by line position. Later, a smarter diff can preserve checked state better when lines are edited or moved.

---

## GitHub Sync Design

Use a private GitHub repository as sync and backup storage.

Recommended repository structure:

```text
my-notes/
  notes/
    note-id-1.md
    note-id-2.md
    note-id-3.md

  images/
    image_001.png
    image_002.jpg

  thumbnails/
    image_001.jpg

  meta/
    index.json
```

Each note can be stored as a Markdown file:

```markdown
---
id: note-id-1
type: note
title: My first note
color: yellow
created: 2026-07-26T10:20:00Z
updated: 2026-07-26T10:25:00Z
deleted: false
images:
  - image-id-1.jpg
---

This is the note body.
```

Avoid storing all notes in one big `notes.json` file, because that creates more sync conflicts.

---

## Sync Method

For the first version, use the GitHub Contents API.

It is easier for an MVP.

Later, if needed, move to the GitHub Git Data API for better batch commits.

### Recommended MVP sync behavior

```text
1. App opens and loads local notes immediately.
2. If internet is available, app checks GitHub.
3. App downloads remote changes.
4. App uploads local changes.
5. If the same note changed on two devices, app creates a conflict copy.
```

### Conflict handling for MVP

If one note changed locally and remotely:

```text
Do not overwrite either version.
Create a conflict copy.
```

Example:

```text
Original note
Original note - conflict from Android 2026-07-26
```

This is safer than automatic merging.

---

## GitHub Authentication

Use a fine-grained GitHub Personal Access Token for your own private app.

Recommended permissions:

```text
Only one private repository
Contents: Read and write
Metadata: Read
```

Do not give full account access if not needed.

### Important security rule

Do not hardcode the token inside the source code.

Bad:

```text
Token written directly in app code
```

Good:

```text
User enters token in app settings
App stores token securely
```

Use Flutter package:

```text
flutter_secure_storage
```

Secure storage by platform:

```text
Windows: Credential Manager
macOS: Keychain
Linux: Secret Service / secure storage
Android: Keystore
iOS: Keychain
```

---

## Sync Activation and GitHub Token Setup

The app should work fully offline even without sync setup.

Sync becomes active only after the user enters GitHub connection details once.

Use the term shown to the user:

```text
GitHub Personal Access Token
```

The user may call it an API key, but technically GitHub uses a token.

---

### Settings Screen: Sync Setup

Recommended settings page:

```text
Settings
  Sync
    GitHub Sync: Off/On
    GitHub username/owner
    Repository name
    Branch: main
    Personal Access Token
    Test Connection
    Save and Enable Sync
    Disconnect GitHub Sync
```

Required fields:

```text
GitHub owner/user name
Repository name
Branch name, default main
Fine-grained Personal Access Token
```

Optional later:

```text
Create repository automatically
Choose existing repository from list
OAuth login
```

For MVP, manual owner/repo/token input is enough.

---

### One-Time Token Save Flow

Recommended user flow:

```text
1. User opens Settings > Sync.
2. User pastes GitHub Personal Access Token.
3. User enters GitHub owner name, repo name, and branch.
4. User clicks Test Connection.
5. App checks GitHub access.
6. If successful, app securely saves token.
7. App saves repo config.
8. App sets sync_enabled = true.
9. Manual Sync button becomes active.
```

After successful setup:

```text
User does not need to paste token again.
Token is preserved securely on that device.
Sync remains enabled until user disables or disconnects it.
```

---

### Token Storage Rule

The GitHub token must not be stored in SQLite or plain text files.

Use:

```text
flutter_secure_storage
```

Store token using a key like:

```text
github_pat
```

The normal settings database can store non-secret config only:

```text
sync_config
  id
  sync_enabled
  github_owner
  github_repo
  github_branch
  last_sync_at
  last_sync_status
  last_remote_commit
```

Do not store token here.

---

### Test Connection Logic

When user clicks Test Connection, the app should call GitHub API:

```text
GET /repos/{owner}/{repo}
GET /repos/{owner}/{repo}/contents?ref={branch}
```

Successful setup requires:

```text
Token is valid
Repository exists
Token has access to the repository
Token has Contents read/write permission
Branch exists
```

If test fails, show clear error:

```text
Invalid token
Repository not found
No permission for this repository
Branch not found
No internet connection
GitHub rate limit reached
```

Do not enable sync until test succeeds.

---

### Sync Enabled State

Recommended logic:

```text
If sync_enabled = false:
  App works local-only.
  Manual Sync button is disabled or shows setup prompt.

If sync_enabled = true and token exists:
  Manual Sync button is active.
  App can sync with GitHub.

If sync_enabled = true but token is missing:
  Disable sync.
  Show "Reconnect GitHub" prompt.
```

Recommended UI states:

```text
Not connected
Connected
Syncing
Last synced just now
Sync failed
Reconnect required
```

---

### Manual Sync Button

For MVP, use manual sync first.

Recommended places for Sync button:

```text
Home top bar
Settings > Sync
Desktop sidebar/footer
```

When clicked:

```text
1. Check sync is enabled.
2. Check token exists in secure storage.
3. Check internet.
4. Run safe sync engine.
5. Show success/failure result.
```

The sync engine must still follow the anti-resurrection rules:

```text
Fetch tombstones first
Apply tombstones locally
Then sync notes/lists
Never blindly re-upload deleted items
```

---

### Disable vs Disconnect

Use two different options.

#### Disable Sync

```text
sync_enabled = false
Token remains saved securely
Local data remains unchanged
User can turn sync on again later without pasting token
```

#### Disconnect GitHub Sync

```text
sync_enabled = false
Delete token from secure storage
Clear GitHub repo config if user confirms
Local notes remain on the device
```

This gives user control without deleting notes.

---

### Token Replacement

The app should not display the saved token again.

Recommended UI:

```text
Token: Saved
[Replace Token]
[Remove Token]
```

If user chooses Replace Token:

```text
User pastes new token
App tests connection
If test succeeds, replace securely saved token
If test fails, keep old token unless user chooses remove
```

---

### Security Notes

Important rules:

```text
Never hardcode token in app code
Never commit token to GitHub
Never save token in logs
Never show token after save
Mask token while typing/pasting
Allow user to remove token
Use the smallest GitHub permission possible
```

Recommended GitHub token permission:

```text
Fine-grained token
Only selected notes repository
Repository permissions > Contents: Read and write
Repository permissions > Metadata: Read
```

---

## GitHub Backup Settings

The app should have a separate Backup option in Settings.

Backup is different from sync.

```text
Sync   = keeps devices updated with latest notes/lists
Backup = creates dated snapshot files for recovery
```

Backup should be optional.

Recommended Settings page:

```text
Settings
  Backup
    GitHub Backup: On/Off
    Backup frequency: Weekly / Monthly
    Backup Now
    Last backup time
    Last backup status
    Backup retention option, optional later
```

Backup can only work if GitHub Sync is connected, because backups are saved to the same GitHub repository.

If GitHub Sync is not connected:

```text
Backup settings show: Connect GitHub Sync first
```

---

### Backup Frequency Logic

Recommended options:

```text
Disabled
Weekly
Monthly
```

Because this app has no server, scheduled backup cannot run exactly at midnight if the app is closed.

Correct local-first behavior:

```text
When app opens, syncs, or comes online:
  Check if backup is due.
  If due, create backup and upload to GitHub.
```

Weekly backup rule:

```text
Create backup if last_backup_at is older than 7 days.
```

Monthly backup rule:

```text
Create backup if last_backup_at is in a previous month or older than about 30 days.
```

Recommended MVP:

```text
Backup runs after successful sync, not before sync.
```

Reason:

```text
After sync, local data is more complete and safer to snapshot.
```

---

### Manual Backup Now

User should also have a manual option:

```text
Backup Now
```

When clicked:

```text
1. Check GitHub is connected.
2. Check internet.
3. Export all current local notes/lists, metadata, checklist states, colors, archive/trash state, and images.
4. Create backup archive file.
5. Upload backup archive to GitHub.
6. Update last_backup_at and last_backup_status.
```

Manual backup should work even if weekly/monthly backup is disabled.

---

### Recommended GitHub Backup Folder

Backups should be stored separately from live sync files.

Recommended structure:

```text
my-notes/
  notes/
  images/
  .tombstones/

  backups/
    weekly/
      notes-backup-weekly-2026-07-27-device-android-phone.zip

    monthly/
      notes-backup-monthly-2026-07-device-windows-laptop.zip

    manual/
      notes-backup-manual-2026-07-27T10-30-00Z-device-windows-laptop.zip
```

Include device ID or device name in backup filename to avoid conflicts between devices.

---

### Recommended Backup File Format

Use a compressed `.zip` file for each backup.

Backup zip contents:

```text
backup.json
notes/
  note-id-1.md
  note-id-2.md
lists/
  list-id-1.md
images/
  image-id-1.jpg
  image-id-2.png
tombstones/
  note-id-deleted.json
```

`backup.json` should include metadata:

```json
{
  "backup_version": 1,
  "created_at": "2026-07-27T10:30:00Z",
  "created_by_device_id": "windows-laptop-abc123",
  "app_version": "1.0.0",
  "item_count": 120,
  "image_count": 15
}
```

The backup should include:

```text
Active items
Archived items
Trash items
Checklist checked/unchecked states
Colors
Images
Tombstones/deletion records
```

Including tombstones is important because restore should not accidentally resurrect deleted notes.

---

### Backup Retention Recommendation

For MVP, keep backups until the user manually deletes them from GitHub.

Optional later setting:

```text
Keep last 4 weekly backups
Keep last 12 monthly backups
Keep manual backups forever
```

GitHub storage warning:

```text
Backups with images can grow large.
Do not allow videos or non-image file attachments.
Compress images where possible.
```

---

### Backup Privacy Warning

Backups saved to GitHub are stored in the GitHub repository and Git history.

Important:

```text
Deleting a backup file later may not remove it from old Git commit history.
```

If notes are sensitive, recommended future feature:

```text
Encrypted backup zip before upload
```

---

## Download / Export Notes and Lists

The app should support downloading/exporting selected notes and lists.

User can select:

```text
Single note/list
Multiple notes/lists
All search results later
```

Recommended selection UI:

```text
Long press or checkbox select on mobile
Ctrl/Cmd click or selection mode on desktop
Toolbar shows: Export / Download
```

---

### Recommended Export Formats

You asked for 3 formats and mentioned PDF and text.

Recommended 3 formats:

```text
1. PDF
2. Plain text (.txt)
3. Markdown (.md)
```

Markdown is recommended as the third format because the app already uses Markdown/text internally and it preserves note formatting better than plain text.

Optional later formats:

```text
HTML
DOCX
JSON backup export
```

---

### Export Behavior for Single Item

If user selects one note/list:

```text
PDF      -> one .pdf file
Text     -> one .txt file
Markdown -> one .md file
```

Recommended filename:

```text
Title - 2026-07-27.pdf
Title - 2026-07-27.txt
Title - 2026-07-27.md
```

If title has unsafe filename characters, clean them.

---

### Export Behavior for Multiple Items

If user selects multiple notes/lists:

Recommended behavior:

```text
Create one .zip file containing exported files.
```

Example:

```text
selected-notes-export-2026-07-27.zip
  Shopping List.md
  Shopping List.txt
  Shopping List.pdf
  Meeting Note.md
  Meeting Note.txt
  Meeting Note.pdf
  images/
    image-id-1.jpg
```

Alternative option later:

```text
Merge selected items into one PDF
```

For MVP, separate files inside one zip is simpler and safer.

---

### PDF Export Rules

PDF should include:

```text
Title
Created date
Updated date
Archive/Trash status if needed
Color indicator, optional
Images
Note body or checklist items
```

Checklist PDF format:

```text
☐ Rice
☑ Milk
☐ Tea
```

PDF should be generated locally on the device.

Recommended Flutter packages later:

```text
pdf
printing
```

---

### Plain Text Export Rules

Plain text should be clean and easy to copy.

Note text export:

```text
Title

Body text
```

Checklist text export recommended default:

```text
Shopping List

[ ] Rice
[x] Milk
[ ] Tea
```

Optional setting later:

```text
Export checklist without checkbox marks
```

---

### Markdown Export Rules

Markdown export should preserve formatting and metadata.

Note Markdown example:

```markdown
---
type: note
title: Meeting Note
created: 2026-07-27T10:00:00Z
updated: 2026-07-27T10:20:00Z
color: yellow
---

# Meeting Note

Body text here.
```

Checklist Markdown example:

```markdown
---
type: checklist
title: Shopping List
created: 2026-07-27T10:00:00Z
updated: 2026-07-27T10:20:00Z
color: green
---

# Shopping List

- [ ] Rice
- [x] Milk
- [ ] Tea
```

---

### Export Storage Destination

Export/download should save to user-chosen location.

Desktop:

```text
Save As dialog
```

Android:

```text
Share sheet or Downloads folder using system file picker
```

The export operation should not require internet.

Recommended rule:

```text
Download/export works from local data offline.
```

---

## Responsive Interface Plan for PC and Mobile

The app should look clean, modern, and polished on both large desktop screens and small mobile screens.

Honest design principle:

```text
A stunning app does not show every feature at once.
A stunning app shows the right action at the right time.
```

Because this app has many features, the interface must use progressive disclosure:

```text
Primary actions are visible.
Secondary actions are inside menus, bottom sheets, or contextual toolbars.
Rare actions stay in Settings.
```

---

### Responsive Breakpoints

Recommended layout breakpoints:

```text
Compact/mobile:   width < 600 dp
Medium/tablet:    600 dp to 1024 dp
Expanded/desktop: width > 1024 dp
```

Flutter can handle this using:

```text
LayoutBuilder
MediaQuery
NavigationRail
NavigationDrawer
BottomSheet
Adaptive layouts
```

---

### Desktop / PC Layout

Desktop has enough space, so use a comfortable multi-column layout.

Recommended desktop layout:

```text
 ---------------------------------------------------------------
| Sidebar | Top Search / Sync Status / New Button               |
|---------|-----------------------------------------------------|
| Home    | All | Notes | Lists                                  |
| Archive |-----------------------------------------------------|
| Trash   | Note/List cards grid                                |
| Settings|                                                     |
|         | [card] [card] [card] [card]                         |
|         | [card] [card] [card] [card]                         |
 ---------------------------------------------------------------
```

Desktop navigation:

```text
Left sidebar or NavigationRail
Home
Archive
Trash
Settings
```

Desktop top bar:

```text
Search bar
New button
Sync button/status
View layout toggle, optional
```

Desktop card actions can appear on hover:

```text
Color
Archive
Trash
More menu
```

Desktop multi-select:

```text
Ctrl/Cmd click or checkbox selection
Context toolbar appears at top
Export / Archive / Trash / Color
```

Optional later desktop power feature:

```text
Ctrl+K command palette
Keyboard shortcuts
```

---

### Desktop Open Item Layout

On desktop, opening a note/list can use a large detail page, modal, or right-side editor panel.

Recommended first version:

```text
Open item in a focused full page or large dialog.
```

Top area:

```text
Back
Title
Checklist checkbox visibility toggle, only for checklist View Mode
View/Edit toggle
Color
Image insert, in Edit Mode
Copy All, in View Mode
More menu
```

For View Mode:

```text
Text is selectable and copyable
Images are visible
Checklist checkbox visibility can be toggled on/off
Checklist checkboxes can be checked/unchecked only when visible
```

For Edit Mode:

```text
Title is editable
Note body is editable
Checklist is plain multiline editable text
Image insert option is visible
```

---

### Home Card Display View Options

The app should support more view options for the card/home screen, similar to but more flexible than Google Keep.

Recommended display modes:

```text
Grid/Masonry View = Google Keep-style cards, default
List View         = full-width cards, easier reading
Compact View      = smaller denser cards, more items visible
```

This applies to:

```text
Home
Archive
Trash
Search results
```

This is a UI preference, not note data.

Recommended saved setting:

```text
settings.card_view_mode = grid/list/compact
```

Recommended rule:

```text
Card view mode should be saved per device locally.
It does not need to sync through GitHub.
```

Desktop placement:

```text
Top toolbar, right side of search bar
Near sync icon and new-note plus icon
Use grid/list/compact icon toggle or a small view-menu icon
```

Desktop suggested toolbar order:

```text
Search | All/Notes/Lists | View Mode icon | Sync icon | New icon | More
```

Mobile placement:

```text
Top app bar, near sync icon
If space is tight, put it inside the ⋮ menu
Tapping opens a bottom sheet with Grid/List/Compact icon choices
```

Mobile suggested top bar:

```text
Search field | View icon | Sync icon | ⋮
```

Recommended icons:

```text
Grid/Masonry View -> grid icon
List View         -> list icon
Compact View      -> density/compact icon
```

Important mobile rule:

```text
Only one view icon should be visible on mobile.
Do not show three separate view buttons on the top bar.
```

---

### Checklist Detail View Options

Checklist/list items need an additional detail-view toggle that normal notes do not have.

Checklist View Mode toolbar should include:

```text
Checkbox visibility toggle
View/Edit toggle
More menu
```

Optional later detail-view density option:

```text
Normal spacing
Compact spacing
```

Recommended placement for optional density:

```text
Desktop: checklist detail toolbar or view menu
Mobile: inside ⋮ menu or same bottom sheet as view options
```

Do not confuse these two concepts:

```text
Home card display mode = grid/list/compact cards
Checklist checkbox toggle = show/hide checkboxes inside one checklist item
```

---

### Mobile Layout

Mobile has limited space, so it must be simpler than desktop.

Recommended mobile home layout:

```text
 -----------------------------
| Search notes...       Sync  |
|-----------------------------|
| All | Notes | Lists         |
|-----------------------------|
| Note/List card              |
| Note/List card              |
| Note/List card              |
|                         +   |
 -----------------------------
```

Recommended mobile navigation:

```text
Home is primary.
Archive and Trash are available from menu/drawer or bottom navigation.
Settings stays inside menu.
```

Best mobile approach:

```text
Top app bar:
  Search
  Sync status icon
  More menu

Filter chips:
  All | Notes | Lists

Floating action button:
  +
```

When user taps `+`, show bottom sheet:

```text
New Note
New List
```

This avoids two separate buttons on a small screen.

---

### Mobile Card Design

Cards should be compact but readable.

Recommended card content:

```text
Title
First few lines
First image thumbnail, if available
Checklist preview, if list
Color background
Small updated time, optional
```

Checklist card preview:

```text
☐ Rice
☑ Milk
☐ Tea
+ 4 more
```

Mobile card actions should not all be visible.

Recommended mobile action behavior:

```text
Tap card       -> open View Mode
Long press     -> enter selection mode
Three-dot menu -> Color / Archive / Trash / Export
Swipe archive  -> optional later, with Undo
```

Do not put Trash as an accidental swipe action in the MVP.

---

### Mobile Open Item Layout

On mobile, opening an item should be full screen.

Recommended View Mode:

```text
 --------------------------------
| Back | Title            Edit ⋮ |
|--------------------------------|
| Images, if any                 |
| Text / checklist content       |
|                                |
 --------------------------------
```

Recommended Edit Mode:

```text
 --------------------------------
| Back | Save/View          ⋮    |
|--------------------------------|
| Editable title                 |
| Image toolbar                  |
| Editable note text             |
| or checklist lines             |
 --------------------------------
```

View/Edit toggle should be obvious but not too large.

Recommended mobile toggle:

```text
View Mode: show [Edit]
Edit Mode: show [View] or [Done]
```

---

### Mobile Action Placement

Because mobile space is small, use this priority order.

Always visible:

```text
Back
Edit/View toggle
Main content
```

Visible in top/right menu:

```text
Copy All
Color
Archive
Move to Trash
Export
Insert image, if in Edit Mode
```

Hidden in Settings:

```text
GitHub token setup
Backup weekly/monthly
Backup Now
Disconnect sync
```

This keeps mobile clean.

---

### Copy Text on Mobile View Mode

Copy support is important.

Recommended behavior:

```text
Long press text -> native select/copy menu
Copy All option -> available in three-dot menu
```

For checklist View Mode:

```text
Tap checkbox -> check/uncheck
Long press line text -> select/copy text
Copy All -> copies whole list
```

This avoids conflict between checking items and selecting text.

---

### Color Picker UI

Use a simple color palette like Google Keep.

Desktop:

```text
Small popover near color button
```

Mobile:

```text
Bottom sheet with color circles
```

Recommended colors:

```text
Default
Red
Orange
Yellow
Green
Teal
Blue
Purple
Pink
Gray
```

---

### Image Insert UI

Image insert should not make the editor crowded.

Desktop Edit Mode:

```text
Image button in top toolbar
Drag and drop image, optional later
Paste image from clipboard, optional later
```

Mobile Edit Mode:

```text
Image button in toolbar or three-dot menu
Choose from gallery
Take photo, optional later
```

Images should display as clean rounded thumbnails inside notes/lists.

---

### Selection and Export UI

Mobile selection:

```text
Long press a card
Selection mode starts
User taps more cards
Top bar shows selected count
Export button appears
```

Desktop selection:

```text
Checkbox or Ctrl/Cmd click
Toolbar shows selected count
Export / Archive / Trash / Color actions
```

Export should not be on the main screen until user selects items.

---

### Sync and Backup UI

Sync should be visible but not distracting.

Recommended sync display:

```text
Small cloud icon
Last synced time in Settings or tooltip
Manual Sync button in menu/top bar
```

Backup should not be on the main home screen.

Backup belongs in:

```text
Settings > Backup
```

Reason:

```text
Backup is important but not used every minute.
```

---

### Visual Style Recommendation

Recommended style:

```text
Material 3
Soft rounded cards
Pastel note colors
Clean typography
Light and dark mode
Subtle shadows
Smooth transitions
Minimal icons
Good empty states
```

The app can look Google Keep-inspired, but should have its own identity.

Good visual direction:

```text
Simple like Google Keep
Safer because of View/Edit mode
More organized because of Notes/Lists groups
More reliable because of local-first sync
```

---

### Icon-First Button and Action Design

The app should use beautiful, meaningful icon-based controls instead of text-heavy buttons.

Recommended rule:

```text
Primary actions should be icon buttons.
Text labels should be avoided on action buttons unless absolutely needed.
```

Examples:

```text
Create note/list      -> plus icon
Search                -> search icon
Card view mode         -> grid/list/compact icon
Checklist checkbox view-> checkbox/list icon
Sync                  -> cloud sync icon
Backup                -> cloud upload / archive icon
Edit                  -> pencil icon
View/Done             -> eye icon or check icon
Copy                  -> copy icon
Copy All              -> copy-all icon
Color                 -> palette icon
Insert image          -> image icon
Archive               -> archive box icon
Restore               -> restore icon
Trash                 -> trash icon
Delete forever        -> trash/delete warning icon
Export/Download       -> download icon
Settings              -> gear icon
More actions          -> three-dot menu icon
```

Important accessibility rule:

```text
Even if buttons are icon-only visually, every button must have tooltip and accessibility label.
```

Desktop:

```text
Hover on icon -> tooltip shows action name
```

Mobile:

```text
Long press icon -> tooltip or hint
Screen reader -> reads semantic label
```

This keeps the interface clean and modern while still understandable.

Recommended Flutter implementation:

```text
IconButton
Tooltip
Semantics label
PopupMenuButton for secondary actions
BottomSheet with icon rows on mobile
```

For dangerous actions such as Empty Trash or Delete Forever, use:

```text
Warning icon
Confirmation dialog
Clear explanation text inside dialog
```

The main UI should be icon-first, but Settings pages can still use readable setting names because settings require clarity.

---

### Content Font Size Setting

Settings must include font size control for note/list content.

Purpose:

```text
Improve note/list readability for users with poor eyesight.
```

Important rule:

```text
This setting changes only note/list content text size.
It should not change the whole app interface size.
```

Affected areas:

```text
Note View Mode body text
Note Edit Mode editor text
Checklist View Mode item text
Checklist Edit Mode multiline editor text
PDF/export font size optional later
```

Not affected:

```text
App bar
Sidebar
Settings labels
Card action icons
System navigation
Dialog buttons
```

Recommended Settings UI:

```text
Settings > Appearance
  Note/List Font Size
    A-   current size   A+
    or slider
```

Recommended options:

```text
Small
Default
Large
Extra Large
```

Recommended numeric scale:

```text
Small       = 14 px
Default     = 16 px
Large       = 18 px
Extra Large = 20 px or 22 px
```

Recommended saved setting:

```text
settings.content_font_scale
```

Example values:

```text
0.90
1.00
1.15
1.30
```

This setting should apply immediately without app restart.

---

### URL Clickable Link Toggle

Settings must include a URL toggle option.

Purpose:

```text
User controls whether URLs inside notes/lists behave as clickable links or plain text.
```

Recommended Settings UI:

```text
Settings > Editor / Reading
  Clickable URLs: On/Off
```

When URL toggle is On:

```text
URLs in notes/lists are detected
URLs are styled as links
Click/tap opens link in browser
```

When URL toggle is Off:

```text
URLs display as normal plain text
Click/tap does not open browser
User can still select and copy the URL text
```

This should apply to both:

```text
Notes
Lists/checklists
```

Recommended behavior by mode:

```text
View Mode:
  If URL toggle On -> links clickable
  If URL toggle Off -> links plain text only

Edit Mode:
  URLs remain editable text
  No accidental browser opening while editing
```

For checklist View Mode:

```text
Checkbox tap area should be separate from link tap area.
If URL toggle is On, tapping URL text opens link.
Tapping checkbox checks/unchecks item.
```

Recommended security behavior:

```text
Ask confirmation before opening unusual/non-http links.
Support http:// and https:// first.
Optional later: mailto:, tel:
```

Recommended saved setting:

```text
settings.clickable_urls_enabled
```

Default recommendation:

```text
Clickable URLs = On
```

But user can turn it Off anytime.

---

### Flutter UI Packages to Consider

Useful Flutter packages later:

```text
flutter_staggered_grid_view  -> masonry/grid cards
flutter_markdown             -> Markdown rendering
pdf                          -> PDF export
printing                     -> PDF preview/print/share
file_picker                  -> desktop image selection with image-only filter
image_picker                 -> mobile camera/gallery
flutter_secure_storage       -> GitHub token storage
```

For MVP, avoid too many UI packages unless necessary.

---

### Interface MVP Recommendation

Start with this UI first:

```text
Desktop:
  Sidebar + search + All/Notes/Lists filters + card grid + full item page

Mobile:
  Search top bar + All/Notes/Lists chips + card list/grid + FAB + full-screen item page
```

Do not build every advanced UI at once.

First make the app feel excellent for these actions:

```text
Create
Open
View
Edit
Check checklist item
Copy text
Change color
Archive
Trash
Sync manually
```

Then add advanced polish.

---

## Recommended MVP Features

Start with a simple but solid version.

### Version 1

- Create note
- Create checklist/list
- Edit note
- Edit checklist as plain multiline text
- Pin/unpin note/list with sync across devices
- Recently edited notes/lists appear on top after sync
- Last viewed/opened time stays local-only by default
- Move note/list to Archive
- Restore note/list from Archive
- Move note/list to Trash
- Restore note/list from Trash
- Move archived note/list to Trash
- Move trashed note/list to Archive
- Empty Trash manually
- Delete forever from Trash
- Search notes locally
- Store notes/lists in SQLite using Drift
- Markdown editor for notes
- Checklist View Mode with checkbox visibility toggle On/Off
- View/Edit mode toggle
- Home card display modes: Grid/Masonry, List, Compact
- Copy selected text in View Mode
- Copy All button in View Mode
- Insert images for notes and lists only; no video or non-image file attachments
- Per-note/list color option like Google Keep
- Icon-first action buttons with tooltips/accessibility labels
- Settings option to increase/decrease note/list content font size only
- Settings option to turn clickable URLs On/Off
- GitHub sync settings page
- User pastes GitHub Personal Access Token one time
- Test GitHub connection before enabling sync
- Preserve token securely using flutter_secure_storage
- Enable/disable sync option
- Disconnect sync option that removes saved token
- Manual GitHub sync button
- Basic sync status display
- GitHub backup settings: disabled/weekly/monthly
- Backup Now button
- Save backup zip files to GitHub
- Select single/multiple notes/lists for export/download
- Export/download as PDF
- Export/download as plain text `.txt`
- Export/download as Markdown `.md`
- Conflict copy handling
- GitHub token saved securely

### Version 2

- Auto sync when app opens
- Auto sync when internet returns
- Markdown preview
- Tags
- Better image management
- Better settings page
- Import/export Markdown folder

### Version 3

- Encrypted GitHub sync
- Better text merge
- Note history
- Background sync
- Obsidian-compatible folder mode

---

## Recommended App Structure

```text
my_notes_app/
  lib/
    main.dart

    features/
      notes/
        note_model.dart
        note_editor_page.dart
        note_list_page.dart

      storage/
        local_database.dart
        note_repository.dart

      sync/
        github_auth.dart
        github_client.dart
        sync_engine.dart
        conflict_resolver.dart

      settings/
        settings_page.dart

      ui/
        app_theme.dart
        responsive_layout.dart
```

---

## Development Environment Recommendation

Yes, VS Code can handle Flutter very well.

Recommended development tools:

```text
Code editor: Visual Studio Code
Flutter SDK: Required
Dart SDK: Comes with Flutter
VS Code extensions: Flutter and Dart
Android testing: Android Studio or Android SDK
Desktop testing: Windows/macOS/Linux desktop support enabled in Flutter
Git: Required for source control
GitHub account: Required for sync target
```

### VS Code extensions to install

Install these in VS Code:

```text
Flutter
Dart
GitLens optional
SQLite Viewer optional
Error Lens optional
```

### Android development requirement

For Android builds, you still need Android Studio or at least Android SDK tools installed.

VS Code is your code editor, but Android SDK provides:

- Android emulator
- Android build tools
- Platform SDK
- Device debugging support

### Desktop development requirement

For desktop builds:

- Windows build requires Windows environment and Visual Studio Build Tools
- macOS build requires macOS and Xcode
- Linux build requires Linux build dependencies

You can write most code in VS Code, but final builds for each OS usually need that OS.

---

## Best Starting Path

Recommended first development target:

```text
1. Build Android + Windows first
2. Make local note create/edit/delete work
3. Add SQLite/Drift database
4. Add Markdown editor
5. Add manual GitHub sync
6. Add conflict handling
7. Later add macOS/Linux builds
```

Do not start with sync first.

Start with:

```text
Local app working perfectly offline
```

Then add:

```text
GitHub sync
```

---

## Final Decision

The best build plan is:

```text
Flutter app
+ Drift/SQLite local database
+ Markdown note editor
+ GitHub private repository sync
+ Fine-grained Personal Access Token
+ Secure token storage
+ Manual sync first
+ Conflict copy handling
```

This matches the main requirement:

```text
No own server
Works offline
Stores data locally
Syncs through GitHub when internet is available
Usable on desktop and mobile
```
