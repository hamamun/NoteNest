#!/usr/bin/env bash
# NoteNest — one-shot Android release build.
#
# This is the script you run on your PC to build a release APK that you
# can install on your phone. It does every step in the right order, and
# it refuses to continue if the INTERNET permission is missing from the
# manifest (that is the bug that makes GitHub sync fail with
# "phone cannot reach GitHub" on a release APK).
#
# Run from the repository root:
#     bash tool/build_android.sh
#
# After it finishes, the path to the APK is printed at the very end.

set -euo pipefail

step() { printf '\n=== %s\n' "$1"; }
ok()   { printf '  [OK] %s\n' "$1"; }
warn() { printf '  [!!] %s\n' "$1"; }
die()  { printf '\nERROR: %s\n' "$1" >&2; exit 1; }

cd "$(dirname "$0")/.."

step "Checking Flutter"
flutter --version || die "Flutter is not installed or not on PATH."

step "Generating Android platform folder"
# `--platforms=android` only — no Windows files touched.
# `-y` accepts the optional Windows desktop dialog automatically.
flutter create . \
  --project-name notenest \
  --org com.notenest \
  --platforms=android \
  -y

step "Restoring NoteNest source over the generated templates"
git checkout -- lib pubspec.yaml analysis_options.yaml test 2>/dev/null \
  || warn "not a git checkout, skipping source restore (this is fine for a tarball)"

step "Ensuring the INTERNET permission is in the main manifest"
# Android grants INTERNET automatically at install, but only when the
# manifest declares it. Flutter's template leaves it out of the MAIN
# manifest (debug/profile builds add it themselves), so a release APK
# built without this step has no network at all and GitHub sync fails
# with "failed host lookup" (errno 7). We patch + verify, and we REFUSE
# to build if the permission is not present.
MANIFEST="android/app/src/main/AndroidManifest.xml"
[ -f "$MANIFEST" ] || die "$MANIFEST not found after flutter create."

if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  sed -i.bak 's|<manifest\(.*\)>|<manifest\1>\n    <uses-permission android:name="android.permission.INTERNET" />|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
  ok "added android.permission.INTERNET"
else
  ok "android.permission.INTERNET already present"
fi

if grep -q "android.permission.INTERNET" "$MANIFEST"; then
  ok "$MANIFEST declares the INTERNET permission"
else
  die "could not add android.permission.INTERNET to $MANIFEST. Add this line by hand inside <manifest ...> and re-run:
    <uses-permission android:name=\"android.permission.INTERNET\" />"
fi

step "Fetching Dart/Flutter packages"
flutter pub get

step "Generating the Drift database code"
dart run build_runner build --delete-conflicting-outputs

step "Generating the launcher icon"
dart run flutter_launcher_icons

step "Building the release APK"
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK" ] || die "build reported success but $APK is missing."

printf '\n========================================================\n'
printf 'BUILD SUCCEEDED\n'
printf '========================================================\n'
printf 'APK file:\n  %s\n' "$APK"
printf '\nNext steps on your PC:\n'
printf '  1. Connect the phone with USB debugging ON.\n'
printf '  2. Uninstall the old app on the phone (long-press the icon -> Uninstall).\n'
printf '  3. Install the new APK:\n'
printf '       adb install -r "%s"\n' "$APK"
printf '\nIf adb is not set up, just copy the APK above to the phone\n'
printf '(USB drive, email, Google Drive...) and tap it to install.\n'
printf 'You may need to enable "Install unknown apps" for the app\n'
printf 'you use to open the APK (Files, Drive, Chrome...).\n'
