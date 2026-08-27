# Contributing to NoteNest

Thanks for taking the time. NoteNest is a small, deliberately opinionated
codebase and pull requests of every size are welcome — a typo fix in the
README counts.

This guide is short on purpose. Read it once; it should take three minutes.

## Ground rules

1. **Never break the tombstone invariant.** Sync must pull tombstones *before*
   it pushes anything, and a tombstoned id must never be uploaded again. This is
   enforced by `test/sync_decision_test.dart`. If a change makes that test fail,
   the change is wrong — not the test.
2. **Never let a note be silently lost or overwritten.** Conflicts produce two
   copies; that behaviour is a feature, not a bug to "clean up".
3. **Never store a token, passphrase or note body outside its designated
   place.** Tokens live in `flutter_secure_storage` only. Anything written to
   disk or to `AppLog` must go through the redaction path.
4. **No new dependencies without a reason in the PR body.** NoteNest avoids
   packages that are abandoned or platform-fragile on purpose — see the comment
   block at the top of `pubspec.yaml` for the three APIs this project steers
   around and why.
5. **Keep the app offline-first.** No feature may require a network round-trip
   to work locally.

## Getting a development build running

```bash
git clone https://github.com/hamamun/NoteNest.git
cd NoteNest
# Windows
powershell -ExecutionPolicy Bypass -File tool\setup.ps1
# Linux / macOS
bash tool/setup.sh
```

The platform runners (`android/`, `windows/`) are generated, not committed.
`dart run build_runner build` is required before the app compiles, because
`lib/data/db/database.g.dart` is generated from the Drift table definitions.

```bash
flutter run -d windows          # desktop
flutter run -d <device-id>      # android
```

## Before you open a pull request

```bash
dart format .
flutter analyze                 # must be clean — CI treats warnings as failures
flutter test                    # must be green
```

If you touched a table definition:

```bash
dart run build_runner build --delete-conflicting-outputs
```

If you touched the entry file format, run the codec test and remember the rule:
**every synced field must round-trip** (front matter → SQLite → front matter).

## Style

- Follow `analysis_options.yaml` (`flutter_lints`). Two-space indents,
  trailing commas on multi-line argument lists.
- `prefer_single_quotes` is not enabled, but single quotes are the house style.
- Public APIs get a `///` doc comment. Comments explain *why* a constraint
  exists, referencing the requirement id (e.g. `X-03`, `G-17`) when one does —
  those ids come from `docs/BUILD_CHECKLIST.md`.
- Prefer small, boring classes over clever ones. `SyncEngine` is the one place
  where ordering matters and it says so in its own doc comment.

## Bug reports

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml). The three
things that let a maintainer reproduce a sync or data bug are:

- the NoteNest version from *Settings → About* (e.g. `1.0.0+1`)
- platform and whether sync was enabled
- what you expected, what happened, and whether the note still exists in the
  GitHub repo (paste the file's front matter, **with the token removed**)

**Never paste a token, passphrase or full note body into an issue.**
If a log line or screenshot contains a token, redact it first — the app redacts
its own logs, but a screenshot of the GitHub page will not.

## Feature requests and ideas

Open a [feature request](.github/ISSUE_TEMPLATE/feature_request.yml) issue
first for anything beyond a small change. Sync semantics, privacy and the data
format are the parts of this project where an upfront conversation saves
everyone a wasted week.

## Pull request checklist

- [ ] One logical change per PR; describe the *why*, not just the *what*
- [ ] `flutter analyze` clean and `flutter test` green locally
- [ ] Tests added or extended when behaviour changes
- [ ] `CHANGELOG.md` updated under **Unreleased** (skip for docs-only fixes)
- [ ] No secrets, tokens, or personal data in the diff, commit message, or screenshots
- [ ] If the UI changed, a screenshot or short recording in the PR body

Prefer `Conventional Commits` (`fix(sync): pull tombstones before listing a dirty folder`),
but it is not enforced.

## Branches and releases

- `main` is the only long-lived branch and must always build.
- Version tags are `vMAJOR.MINOR.PATCH`; the `pubspec.yaml` version is
  `MAJOR.MINOR.PATCH+BUILD` and `tool/windows_installer.iss` must match it.
- Release notes are written by hand into the GitHub Release, summarising the
  `CHANGELOG.md` entries since the last tag.

## What is out of scope

Things to skip unless you want to argue for them first: any cloud service owned
by someone other than the user, telemetry of any kind, account systems,
real-time multi-user collaborative editing, and inline images inside a note body
(slated for `v1.2`).

## Licensing

By opening a pull request you confirm the contribution is yours to give and is
offered under the project's [MIT License](/LICENSE), and you agree that the
name and monogram are **not** licensed to you for branding a derivative, as
explained in the README.
