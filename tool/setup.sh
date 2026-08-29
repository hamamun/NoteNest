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
# Android grants INTERNET automatically at install, but only when the
# manifest declares it. Flutter's template leaves it out of the MAIN
# manifest (debug/profile builds add it themselves), so a release APK
# built without this step has no network at all. Patch + verify so a
# missing permission can never ship silently.
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "  ERROR: $MANIFEST not found — run 'flutter create . --platforms=android' first." >&2
  exit 1
fi
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  sed -i.bak 's|<manifest\(.*\)>|<manifest\1>\n    <uses-permission android:name="android.permission.INTERNET" />|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
  echo "  added android.permission.INTERNET"
else
  echo "  already present"
fi
if grep -q "android.permission.INTERNET" "$MANIFEST"; then
  echo "  OK: $MANIFEST declares the INTERNET permission"
else
  echo "  ERROR: could not add android.permission.INTERNET to $MANIFEST" >&2
  echo "  Add this line inside <manifest ...> by hand, then re-run setup:" >&2
  echo '    <uses-permission android:name="android.permission.INTERNET" />' >&2
  exit 1
fi

step "Fetching packages"
flutter pub get

step "Generating the Drift database code"
dart run build_runner build --delete-conflicting-outputs

step "Generating the launcher icons (Windows + Android)"
dart run flutter_launcher_icons
# Replace the generated .ico with the committed multi-size one so the icon
# stays crisp at 16/24/32 px taskbar and Start-menu sizes.
if [ -f "assets/icon/app_icon.ico" ] && [ -d "windows/runner/resources" ]; then
  cp assets/icon/app_icon.ico windows/runner/resources/app_icon.ico
  echo "  windows/runner/resources/app_icon.ico updated"
fi

step "Analyzing"
flutter analyze || echo "  (analyzer reported issues - review above)"

step "Running tests"
flutter test

printf '\nSetup complete.\n'
printf 'Run:    flutter run -d windows   (or: flutter run -d <android-device>)\n'
printf 'Build:  flutter build windows    /   flutter build apk --release\n'
