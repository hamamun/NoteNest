# NoteNest — Windows setup
#
# Generates the Windows + Android platform folders around the app source in
# this repository, then builds the generated database code.
#
# Run from the repository root:
#     powershell -ExecutionPolicy Bypass -File tool\setup.ps1

$ErrorActionPreference = "Stop"

function Step($msg) { Write-Host "`n=== $msg" -ForegroundColor Cyan }

Step "Checking Flutter"
flutter --version
if ($LASTEXITCODE -ne 0) { throw "Flutter is not on PATH. Install it first: https://docs.flutter.dev/get-started/install/windows" }

Step "Enabling desktop support"
flutter config --enable-windows-desktop | Out-Null

Step "Generating platform folders (windows + android only)"
# flutter create fills in the android/ and windows/ runners without touching
# files that already exist... except a few templates, which we restore below.
flutter create . --project-name notenest --org com.notenest --platforms=windows,android

Step "Restoring NoteNest source over the generated templates"
# flutter create rewrites lib/main.dart and pubspec.yaml from its template.
git checkout -- lib pubspec.yaml analysis_options.yaml test 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "  (skipped: not a git checkout — make sure lib/ and pubspec.yaml are the NoteNest versions)" -ForegroundColor Yellow
}

Step "Adding the INTERNET permission for release builds"
$manifest = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
  $content = Get-Content $manifest -Raw
  if ($content -notmatch 'android.permission.INTERNET') {
    $content = $content -replace '(<manifest[^>]*>)', "`$1`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
    Set-Content $manifest $content -NoNewline
    Write-Host "  added INTERNET permission"
  } else {
    Write-Host "  already present"
  }
}

Step "Fetching packages"
flutter pub get

Step "Generating the Drift database code"
dart run build_runner build --delete-conflicting-outputs

Step "Generating the launcher icons (Windows + Android)"
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { throw "flutter_launcher_icons failed" }
# Replace the generated .ico with the committed multi-size one so the icon
# stays crisp at 16/24/32 px taskbar and Start-menu sizes.
if (Test-Path "assets\icon\app_icon.ico") {
  Copy-Item "assets\icon\app_icon.ico" "windows\runner\resources\app_icon.ico" -Force
  Write-Host "  windows\runner\resources\app_icon.ico updated"
}

Step "Analyzing"
flutter analyze
if ($LASTEXITCODE -ne 0) { Write-Host "  (analyzer reported issues - review above)" -ForegroundColor Yellow }

Step "Running tests"
flutter test

Write-Host "`nSetup complete." -ForegroundColor Green
Write-Host "Run on Windows:  flutter run -d windows"
Write-Host "Run on Android:  flutter run -d <device-id>    (flutter devices)"
Write-Host "Build release:   flutter build windows   /   flutter build apk --release"
