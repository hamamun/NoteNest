#!/usr/bin/env bash
# NoteNest — Linux/macOS setup (for development; v1 ships Windows + Android)
#
# Run from the repository root:
#     bash tool/setup.sh

set -euo pipefail

step() { printf '\n=== %s\n' "$1"; }

step "Checking Flutter"
flutter --version

step "Generating platform folders (windows + android only)"
flutter create . --project-name notenest --org com.notenest --platforms=windows,android

step "Restoring NoteNest source over the generated templates"
git checkout -- lib pubspec.yaml analysis_options.yaml test 2>/dev/null \
  || echo "  (skipped: not a git checkout)"

step "Adding the INTERNET permission for release builds"
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ] && ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  sed -i.bak 's|<manifest\(.*\)>|<manifest\1>\n    <uses-permission android:name="android.permission.INTERNET" />|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
  echo "  added INTERNET permission"
else
  echo "  already present or manifest missing"
fi

step "Fetching packages"
flutter pub get

step "Generating the Drift database code"
dart run build_runner build --delete-conflicting-outputs

step "Analyzing"
flutter analyze

step "Running tests"
flutter test

printf '\nSetup complete.\n'
printf 'Run:    flutter run -d windows   (or: flutter run -d <android-device>)\n'
printf 'Build:  flutter build windows    /   flutter build apk --release\n'
