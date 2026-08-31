# NoteNest — one-shot Android release build (Windows).
#
# This is the script you run on your PC to build a release APK that you
# can install on your phone. It does every step in the right order, and
# it refuses to continue if the INTERNET permission is missing from the
# manifest (that is the bug that makes GitHub sync fail with
# "phone cannot reach GitHub" on a release APK).
#
# Run from the repository root in PowerShell:
#     powershell -ExecutionPolicy Bypass -File tool\build_android.ps1
#
# After it finishes, the path to the APK is printed at the very end.

$ErrorActionPreference = "Stop"

function Step($msg) { Write-Host "`n=== $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "`nERROR: $msg" -ForegroundColor Red; exit 1 }

Set-Location (Join-Path $PSScriptRoot "..")

Step "Checking Flutter"
try { flutter --version | Out-Null } catch { Die "Flutter is not installed or not on PATH." }

Step "Generating Android platform folder"
# --platforms=android only so we do not touch Windows files.
# Note: flutter create has no -y/--yes flag; the command is already
# non-interactive, so passing -y aborts the whole script.
flutter create . `
  --project-name notenest `
  --org com.notenest `
  --platforms=android

Step "Restoring NoteNest source over the generated templates"
try {
  git checkout -- lib pubspec.yaml analysis_options.yaml test 2>$null
} catch {
  Warn "not a git checkout, skipping source restore (this is fine for a tarball)"
}

Step "Ensuring the INTERNET permission is in the main manifest"
# Android grants INTERNET automatically at install, but only when the
# manifest declares it. Flutter's template leaves it out of the MAIN
# manifest (debug/profile builds add it themselves), so a release APK
# built without this step has no network at all and GitHub sync fails
# with "failed host lookup" (errno 7). We patch + verify, and we REFUSE
# to build if the permission is not present.
$manifest = "android\app\src\main\AndroidManifest.xml"
if (-not (Test-Path $manifest)) { Die "$manifest not found after flutter create." }

$content = Get-Content $manifest -Raw
if ($content -notmatch 'android\.permission\.INTERNET') {
  $content = $content -replace '(<manifest[^>]*>)', "`$1`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
  Set-Content $manifest $content -NoNewline
  Ok "added android.permission.INTERNET"
} else {
  Ok "android.permission.INTERNET already present"
}

$content = Get-Content $manifest -Raw
if ($content -match 'android\.permission\.INTERNET') {
  Ok "$manifest declares the INTERNET permission"
} else {
  Die "could not add android.permission.INTERNET to $manifest. Add this line by hand inside <manifest ...> and re-run:
    <uses-permission android:name=`"android.permission.INTERNET`" />"
}

Step "Fetching Dart/Flutter packages"
flutter pub get

Step "Generating the Drift database code"
dart run build_runner build --delete-conflicting-outputs

Step "Generating the launcher icon"
dart run flutter_launcher_icons

Step "Building the release APK"
flutter build apk --release

$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) { Die "build reported success but $apk is missing." }

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "BUILD SUCCEEDED" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "APK file:"
Write-Host "  $apk"
Write-Host ""
Write-Host "Next steps on your PC:"
Write-Host "  1. Connect the phone with USB debugging ON."
Write-Host "  2. Uninstall the old app on the phone (long-press the icon -> Uninstall)."
Write-Host "  3. Install the new APK:"
Write-Host "       adb install -r `"$apk`""
Write-Host ""
Write-Host "If adb is not set up, just copy the APK above to the phone"
Write-Host "(USB drive, email, Google Drive...) and tap it to install."
Write-Host "You may need to enable 'Install unknown apps' for the app"
Write-Host "you use to open the APK (Files, Drive, Chrome...)."
