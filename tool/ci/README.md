# NoteNest pipelines

`ci.yml` and `build.yml` are staged here rather than in `.github/workflows/`,
because GitHub only reads workflow definitions from that exact path and they
have to be added by someone whose token has the `workflows` permission.
To turn them on:

```bash
mkdir -p .github/workflows
git mv tool/ci/ci.yml tool/ci/build.yml .github/workflows/
git commit -m "ci: enable the CI and release-build workflows"
git push
```

Move the whole folder or leave this README behind — either is fine. Once
`ci.yml` is in place, the CI badge in the README starts reporting.

## `ci.yml`

| Job | Runner | What it proves |
|-----|--------|----------------|
| `analyze` | ubuntu-latest | `flutter analyze` is clean, and the generated Drift code still matches the schema (a `build_runner` run must produce no diff) |
| `test` | ubuntu-latest **and** windows-latest | the five suites pass on both platforms — the sync decision table and the file codec are the ones worth proving on Windows |
| `format` | ubuntu-latest | `dart format` suggestions. Advisory by design: an unformatted pull request should get a hint, not a blocked pipeline |

Neither `android/` nor `windows/` needs to be generated for these jobs; the
Dart sources are complete on their own, which is why `flutter create` is not
part of CI for analyze/test.

## `build.yml`

Runs on `v*` tags and on `workflow_dispatch`.

| Job | Output |
|-----|--------|
| `version` | reads `MAJOR.MINOR.PATCH` out of `pubspec.yaml` so no version is duplicated in workflow settings |
| `windows` | `flutter build windows --release`, the folder zipped as a portable build, plus `NoteNest-Setup-<version>.exe` compiled by Inno Setup |
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
