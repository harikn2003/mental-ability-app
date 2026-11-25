# NplusPrep — Mental Ability Trainer

![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.8%2B-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android-green)
![Offline](https://img.shields.io/badge/Network-Fully%20offline-brightgreen)

An offline Android app that trains children for the mental ability part of the Navodaya entrance
exam (JNVST, class 6). Built as part of the IIT Madras WSAI internship.

Every question is generated on the device by code: no server, no login, no internet, no question
images or question banks.

**Install:** download `app-release.apk` from the
[latest release](https://github.com/harikn2003/mental-ability-app/releases).

## Features

- **11 topics**, matching the JNVST parts: Odd Man Out, Figure Match, Pattern Completion, Figure
  Series, Analogy, Geo Completion, Mirror Shape, Mirror Text/Clock, Punch Hole, Space
  Visualisation, Embedded Figure
- **3 levels:** Easy (grades 2–3, one change per question), Medium, Hard (real exam level)
- **3 languages:** English, Hindi, Marathi
- **Intelligent Bias:** a wrong answer makes that topic come up more often, a right answer less
- **Answer explanations:** after a wrong, skipped or timed-out answer, a short wordless animation
  acts out the rule on the question's own figures and ends on the correct option
- **Printed papers:** a differently shuffled 40-question paper per student as a PDF, plus a
  teacher's answer key
- **Coordinator tools:** session setup (topic, level, timer of 30 s / 1 min / 2 min / unlimited),
  session history, per-question review, results per topic

## Set up a development PC

One command installs Git, VS Code, Java 17, Flutter, the Android SDK and the VS Code Flutter
extension, then clones this project. Safe to run again; it reuses what is already installed.

**Windows** (PowerShell):

```powershell
Invoke-WebRequest "https://raw.githubusercontent.com/harikn2003/mental-ability-app/master/tools/setup_windows.ps1" -OutFile setup_windows.ps1
powershell -ExecutionPolicy Bypass -File setup_windows.ps1 -ProjectDir "$HOME\StudioProjects\mental_ability_app"
```

**Linux** (Debian/Ubuntu or Fedora):

```bash
curl -fsSLO https://raw.githubusercontent.com/harikn2003/mental-ability-app/master/tools/setup_linux.sh
bash setup_linux.sh --project-dir ~/projects/mental_ability_app
```

Then open a new terminal and run `flutter doctor`. Add `-DryRun` / `--dry-run` to see the steps
without installing anything.

## Everyday commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run                      # debug app on a connected phone
flutter build apk --release
```

## Project layout

```
lib/
  config/     strings (EN/HI/MR), version and build codename
  data/       session history (Hive)
  engine/     question generators, difficulty levels, answer explanations
  painters/   figure drawing (CustomPainter; no image assets)
  paper/      printed-paper PDF
  screens/    session setup, quiz, results, history, review, print
  widgets/    question, option and explanation views
test/         generator checks, rendering checks, release tool checks
tools/        one-step setup scripts
tool/         release.dart
```

## Releases

```bash
dart run tool/release.dart
```

Run on `master`. It asks for the tag (Enter for the next beta), runs `flutter analyze` and
`flutter test`, updates the version, commits, tags and pushes. GitHub Actions then builds the
signed APK and publishes the release.

Release builds are signed with the key named in `android/key.properties` (never committed); CI
reads it from four `ANDROID_*` repository secrets. Losing the key means users must uninstall to
update, so see the handover's "Release signing" section before changing anything there.

## More documentation

- `docs/handover/handover.pdf` — full handover: setup, architecture, testing, releases, signing
- `docs/hard-mode-history.md` — bugs already found and fixed in the Hard engine; read before
  changing it
- `docs/release_beta.md` — release checklist
