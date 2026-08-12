# SportsHub Android migration

The `codex/Android` branch now contains a native Android application alongside
the original SwiftUI sources. Android Studio can open this repository root as a
Gradle project.

## Local baseline

- Android Studio 2025.3
- Android Gradle Plugin 9.0.1
- Gradle 9.2.1
- Android Studio JBR 21; Java source/target compatibility 17
- Compile/target SDK 36; minimum SDK 26
- Jetpack Compose with Material 3

`local.properties` is intentionally ignored because it contains a
machine-specific SDK path. Android Studio will create it when the project is
opened on another computer.

## Implemented Android journey

- Arabic-first onboarding with English switching, RTL/LTR, explicit skip and
  local team follows.
- Five native root destinations: Home, Matches, Explore, Following and Profile.
- Match filters and a match center with summary, events, stats and a local demo
  reminder state.
- Fictional news cards and a clearly labelled demo-data provenance banner.
- Program catalog filtered by sport, provider-authored episode membership and
  program/video detail navigation.
- Playback-right boundary: every demo episode is explicitly non-playable and
  carries an unavailable reason. Program membership never grants playback.
- Local preferences persisted with `SharedPreferences`; no credentials,
  account data, protected media or third-party branding are bundled.

## Verification commands

Run from PowerShell with Android Studio's JBR available:

```powershell
$env:JAVA_HOME = 'D:\Android Studio\jbr'
.\gradlew.bat testDebugUnitTest
.\gradlew.bat assembleDebug
.\gradlew.bat connectedDebugAndroidTest
```

The APK is generated at `app/build/outputs/apk/debug/app-debug.apk`.
