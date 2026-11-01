# NoteNest pipelines

Both workflows are live: GitHub runs them from this folder.

*(They were staged in `tool/ci/` until a token with the `workflows` permission
could add them — that move has since been made, so the files now sit where
GitHub reads them.)*

## `ci.yml`

Runs on every push to `main`, on every pull request into `main`, and on demand.

| Job | Runner | What it proves |
|-----|--------|----------------|
| `analyze` | ubuntu-latest | `flutter analyze --no-fatal-infos` is clean (info-level lints are advisory, like the format job; errors and warnings still fail), and the generated Drift code still matches the schema (a `build_runner` run must produce no diff) |
| `test` | ubuntu-latest **and** windows-latest | the test suites pass on both platforms — the sync decision table and the file codec are the ones worth proving on Windows |
| `format` | ubuntu-latest | `dart format` suggestions. Advisory by design: an unformatted pull request should get a hint, not a blocked pipeline |

Neither `android/` nor `windows/` needs to be generated for these jobs; the
Dart sources are complete on their own, which is why `flutter create` is not
part of CI for analyze/test.

## `build.yml`

Runs on `v*` tags and on `workflow_dispatch` (Actions → **Build** → **Run
workflow**). A manual run is the easiest way to get a fresh `.exe` and `.apk`
without installing anything locally.

> `workflow_dispatch` only appears once the workflow file is on the default
> branch, so the Run-workflow button for `build.yml` exists after this lands on
> `main`. Pushing a `v*` tag works the same way and additionally fills in the
> draft release.

Both workflows follow the **latest stable** Flutter channel rather than a
pinned patch: `pubspec.lock` is git-ignored, so `pub` resolves current package
versions, and a pinned SDK eventually stops being able to compile them (a pinned
3.24.5 could not build `dynamic_color` 1.9, which needs Flutter 3.27+).

| Job | Output |
|-----|--------|
| `version` | reads `MAJOR.MINOR.PATCH` out of `pubspec.yaml` so no version is duplicated in workflow settings |
| `windows` | `flutter build windows --release`, the folder as a portable artifact, plus `NoteNest-Setup-<version>.exe` compiled by Inno Setup |
| `android` | `flutter build apk --release` |
| `release` | a **draft** GitHub Release with the artifacts attached and `.github/RELEASE_TEMPLATE.md` as the body, version placeholders filled in |

Deliberate choices:

- the release stays a **draft** — a build server is not a publisher
- **nothing is signed**. There is no authenticode certificate and no Android
  upload keystore here, and there must not be: those belong to whoever ships
  the app. SmartScreen and the Android sideload warning are therefore expected
  and are documented in the README rather than worked around
- artifacts are uploaded for every run, including pull-request runs, so a
  contributor without a Flutter SDK can still test their change on a device
