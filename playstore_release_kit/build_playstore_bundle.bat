@echo off
echo ==============================================================
echo    BIZPILOT AI - PRODUCTION PLAY STORE BUILDER (.AAB ^& .APK)
echo ==============================================================
cd /d "%~dp0\..\bizpilot_app"

echo [+] Resolving dependencies...
call flutter pub get

echo [+] Compiling Signed Production Android App Bundle (.aab)...
call flutter build appbundle --release

echo [+] Compiling Signed Release APK for direct testing (.apk)...
call flutter build apk --release

echo [+] Copying release bundles to Play Store Kit...
copy /y "build\app\outputs\bundle\release\app-release.aab" "%~dp0app_bundle\app-release.aab"
copy /y "build\app\outputs\flutter-apk\app-release.apk" "%~dp0app_bundle\app-release.apk"

echo ==============================================================
echo    BUILD COMPLETE!
echo    Target: %~dp0app_bundle\
echo ==============================================================
pause
