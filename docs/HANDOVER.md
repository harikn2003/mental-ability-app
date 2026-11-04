# NplusPrep: Project Handover

**For:** the incoming project owner
**From:** Hari (developer), November 2026
**State at handover:** beta 8 (`v1.0.0-beta.8`), released 3 Nov 2026, all 247 automated tests passing

This document explains the whole project from the ground up: what it is, how to set up a computer to work on it, how it is built, how we work, every major problem we hit and how it was fixed, and how to deal with problems in future. No earlier knowledge of Flutter or Android is assumed.

---

## Contents

1. [The project in one page](#1-the-project-in-one-page)
2. [Setting up a computer from zero](#2-setting-up-a-computer-from-zero)
3. [Daily tasks: run, test, build](#3-daily-tasks-run-test-build)
4. [How the app is built](#4-how-the-app-is-built)
5. [How questions are made](#5-how-questions-are-made)
6. [The printed test paper](#6-the-printed-test-paper)
7. [How we work: testing, feedback, releases](#7-how-we-work-testing-feedback-releases)
8. [History: how the project grew](#8-history-how-the-project-grew)
9. [Problems we hit and how we fixed them](#9-problems-we-hit-and-how-we-fixed-them)
10. [Troubleshooting future problems](#10-troubleshooting-future-problems)
11. [Access, accounts and loose ends](#11-access-accounts-and-loose-ends)
12. [Glossary](#12-glossary)

---

## 1. The project in one page

**What it is.** NplusPrep is an Android app that trains children for the Mental Ability Test of the JNVST, the entrance exam for Jawahar Navodaya Vidyalaya (class 6). The test is 40 picture-based reasoning questions in 10 parts. The app makes unlimited practice questions of the same kinds, checks answers, adapts to each child's weak topics, and can print exam-style papers for a whole class.

**Who uses it.**

| Who | What they do |
|---|---|
| Children (about 11 years old; Easy level is for grades 2-3) | Take quiz sessions on a phone or tablet |
| Coordinators / teachers | Set up sessions on the config screen, read results, print papers |
| Mentors | Test builds, report problems in the Notion tracker, review printed papers |

**Key facts.**

- **Fully offline.** No server, no login, no internet. Every question is generated on the device by code; there are no question images or question banks.
- **11 topics:** Odd Man Out, Figure Match, Pattern Completion, Figure Series, Analogy, Geo Completion, Mirror Shape, Mirror Text/Clock, Punch Hole, Space Visualisation, Embedded Figure. These match the JNVST parts (Mirror is split into shapes and text).
- **3 levels:** Easy (grades 2-3, one change per question), Medium (midway), Hard (real exam level).
- **3 languages:** English, Marathi, Hindi.
- **Intelligent Bias:** a wrong answer makes that topic come up more often (+2 weight, up to 10); a right answer makes it less frequent (-1, down to 1).
- **Printed papers:** a coordinator picks a number of students and a language; the app makes a PDF with a differently shuffled 40-question paper per student (one A4 sheet, both sides) and a teacher's answer key.

**Where things are.**

| Thing | Location |
|---|---|
| Code | GitHub: https://github.com/harikn2003/mental-ability-app |
| Releases (APK to install) | https://github.com/harikn2003/mental-ability-app/releases |
| Bug / feature tracker | Notion: "Navodaya Mental Ability Issues DB" (shared Notion workspace) |
| Package name (release app) | `com.nplusone.maa.mental_ability_app` |
| Package name (debug app) | `com.nplusone.maa.mental_ability_app.debug` (installs beside the release app) |

---

## 2. Setting up a computer from zero

The project can be developed on **Windows 10/11** or **Linux** (Ubuntu/Debian or Fedora). The setup is deliberately light: **Visual Studio Code** as the editor and Android's **command-line tools** instead of Android Studio. That is about 1.5 GB of downloads and far less memory while working, compared with 3-4 GB and a heavy IDE. Allow 30-60 minutes, mostly downloads.

> **Note:** "Visual Studio Code" (VS Code) is the free, lightweight editor - not "Visual Studio", the large Windows IDE, which is not needed at all.

### 2.1 What gets installed

| Tool | Why | Installed from (Windows / Linux) |
|---|---|---|
| **Git** | Version control; on Windows also gives **Git Bash**, used by the release hook | winget / apt or dnf |
| **Visual Studio Code** + **Flutter extension** | Editor with code completion, run and debug buttons | winget / snap, or the Microsoft package |
| **Java 17** (or any Java 17+ already installed) | Android builds run on Java | winget (Temurin) / apt or dnf (OpenJDK) |
| **Flutter SDK** (stable) | The app framework; includes Dart | Git clone of the stable branch |
| **Android SDK command-line tools**: platform-tools (`adb`), Android 36, build-tools 36, NDK 27 | Builds and installs the Android app | Google's download, then `sdkmanager` |
| **zenity** (Linux only) | Dialog boxes for the release hook | apt or dnf |

Install locations: Flutter in `C:\src\flutter` (Windows) or `~/development/flutter` (Linux); the Android SDK in `%LOCALAPPDATA%\Android\Sdk` (Windows) or `~/Android/Sdk` (Linux).

Both setup scripts install only what is missing, set the paths, accept the Android licences, install the VS Code extension, can clone the project, switch on the release hook, and finish with `flutter doctor`. Both have a dry-run mode that shows what they would do without changing anything.

### 2.2 Windows: one-step setup

Open **PowerShell** and run:

```powershell
# 1. Get the script (or copy tools\setup_windows.ps1 from the repository)
Invoke-WebRequest https://raw.githubusercontent.com/harikn2003/mental-ability-app/master/tools/setup_windows.ps1 -OutFile setup_windows.ps1

# 2. Run it; it also clones the project into the folder you give
powershell -ExecutionPolicy Bypass -File setup_windows.ps1 -ProjectDir "$HOME\StudioProjects\mental_ability_app"
```

- Windows may ask for permission while installing Git, VS Code and Java: click **Yes**.
- Add `-DryRun` to see what it would do without changing anything.
- When it finishes, **close PowerShell and open a new one** so the new paths take effect, then run `flutter doctor`.

### 2.3 Linux: one-step setup

Open a terminal and run:

```bash
# 1. Get the script (or copy tools/setup_linux.sh from the repository)
curl -fsSLO https://raw.githubusercontent.com/harikn2003/mental-ability-app/master/tools/setup_linux.sh

# 2. Run it; it also clones the project into the folder you give
bash setup_linux.sh --project-dir ~/projects/mental_ability_app
```

- It asks for your password (`sudo`) to install system packages.
- Add `--dry-run` to see what it would do without changing anything.
- When it finishes, open a **new terminal** (or run `source ~/.bashrc`), then run `flutter doctor`.
- To use a phone over USB, add yourself to the `plugdev` group once and log out and in: `sudo usermod -aG plugdev "$USER"`.

> **Tip:** On either system, `flutter doctor` should show green ticks for Flutter, the Android toolchain and VS Code. Warnings for "Visual Studio", "Chrome" or "Linux toolchain" can be ignored: those are only for desktop and web builds, which this project doesn't use. The first app build downloads a few more Android parts automatically; that is normal.

### 2.4 Open the project in VS Code

```bash
code ~/projects/mental_ability_app          # Linux
code "$HOME\StudioProjects\mental_ability_app"   # Windows (PowerShell)
```

1. VS Code offers to install the **recommended extensions** (Flutter and Dart, listed in `.vscode/extensions.json`): click **Install**.
2. Pick the device in the bottom-right status bar (your phone, once connected - see 2.6).
3. Open `lib/main.dart` and press **F5** to run with debugging, or **Ctrl+F5** to run without. Save a file to hot-reload.
4. **Ctrl+Shift+P → "Flutter: Run Flutter Doctor"** checks the setup from inside VS Code.

> **Important:** The setup scripts switch on the project's **pre-push release hook** (`git config core.hooksPath tools/git-hooks`). If you clone the project another way, run that command once in the new folder (on Linux also `chmod +x tools/git-hooks/pre-push`). Without it, pushing master won't offer to make a beta, and the two version files can drift apart.

### 2.5 Manual setup (if a script can't be used)

**Windows**

1. Install the tools:
   ```powershell
   winget install --id Git.Git -e
   winget install --id Microsoft.VisualStudioCode -e
   winget install --id EclipseAdoptium.Temurin.17.JDK -e
   ```
2. Flutter: `git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter`, then add `C:\src\flutter\bin` to your user `Path` (Start → "Edit environment variables for your account"). Use a folder **without spaces**.
3. Android command-line tools: from https://developer.android.com/studio#command-line-tools-only download "Command line tools only" for Windows and unzip so that `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat` exists. Set the user variable `ANDROID_HOME` to `%LOCALAPPDATA%\Android\Sdk`, and add its `platform-tools` and `cmdline-tools\latest\bin` folders to `Path`.

**Linux (Ubuntu/Debian; use `dnf` and the Fedora package names on Fedora)**

1. Install the tools:
   ```bash
   sudo apt-get update
   sudo apt-get install -y git curl unzip xz-utils zip libglu1-mesa openjdk-17-jdk zenity
   sudo snap install code --classic
   ```
2. Flutter: `git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter`.
3. Android command-line tools: download "Command line tools only" for Linux from the same page and unzip so that `~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager` exists.
4. Add to `~/.bashrc`, then open a new terminal:
   ```bash
   export ANDROID_HOME="$HOME/Android/Sdk"
   export PATH="$HOME/development/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
   ```

**Both systems, in a new terminal**

1. Android packages and licences:
   ```bash
   sdkmanager --licenses
   sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;27.0.12077973"
   flutter doctor --android-licenses
   code --install-extension Dart-Code.flutter
   ```
2. Get the code (on Windows use `$HOME\StudioProjects\mental_ability_app` as the folder):
   ```bash
   git clone https://github.com/harikn2003/mental-ability-app.git ~/projects/mental_ability_app
   cd ~/projects/mental_ability_app
   flutter pub get
   git config core.hooksPath tools/git-hooks
   ```

The project was last built with **Flutter 3.41.9 (stable)**. Optional: the **GitHub CLI** (`winget install --id GitHub.cli -e` on Windows, `sudo apt-get install gh` on Linux, then `gh auth login`) checks releases and CI from the terminal.

### 2.6 Connect a phone

The app is tested on a real Android phone (a Nothing Phone (2a), model A142).

1. On the phone: **Settings → About phone → tap "Build number" 7 times** to unlock Developer options.
2. **Settings → System → Developer options → turn on "USB debugging"** (and "Wireless debugging" to work without a cable).
3. **With a cable:** plug in and accept the "Allow USB debugging?" prompt on the phone. On Linux, if `adb devices` shows "no permissions", check you are in the `plugdev` group (2.3) and reconnect.
4. **Without a cable (Wi-Fi):** phone and PC on the same Wi-Fi. In Developer options → Wireless debugging → "Pair device with pairing code". On the PC:
   ```bash
   adb pair <ip>:<pairing-port>     # type the 6-digit code shown on the phone
   adb devices                      # the phone should be listed as "device"
   ```
5. Check: `adb devices` lists the phone, and `flutter devices` shows it.

Wireless debugging switches itself off when the phone sleeps or changes network; if `adb devices` is empty, turn it back on (section 10.2).

---

## 3. Daily tasks: run, test, build

All commands run in the project folder and are the same on Windows and Linux; only paths differ (`build\app\...` on Windows, `build/app/...` on Linux).

| Task | Command | Notes |
|---|---|---|
| Run on the phone (debug, hot reload) | `flutter run` | Press `r` to reload after editing code, `R` to restart, `q` to quit |
| Install a debug build without running from the PC | `flutter build apk --debug` then `adb install -r build\app\outputs\flutter-apk\app-debug.apk` | Installs as the **debug** app, beside the release app |
| Open the installed debug app | `adb shell monkey -p com.nplusone.maa.mental_ability_app.debug -c android.intent.category.LAUNCHER 1` | |
| Check code style and errors | `flutter analyze` | Must say "No issues found!" |
| Run all tests | `flutter test` | About 1-3 minutes; must end "All tests passed!" (247 at handover) |
| Run one test file | `flutter test test/series_test.dart` | |
| Release build (local check only) | `flutter build apk --release` | Output in `build\app\outputs\flutter-apk\app-release.apk` |
| Preview on a phone without installing | `dart run tool/phone_preview.dart` | Opens the app in the phone's browser via a QR code; see `docs/phone_preview.md` |

If `adb` lists the phone twice (once by IP, once by name), add `-s <name>` to every `adb` command, e.g. `adb -s adb-000553435000367-g9vzXa._adb-tls-connect._tcp install -r ...`.

---

## 4. How the app is built

### 4.1 Technology

| Layer | Technology | Why it was chosen |
|---|---|---|
| Language / framework | **Dart 3.8 + Flutter** | One codebase; fast 2D canvas drawing, which matters because every figure is drawn by code |
| Drawing | Flutter **`CustomPainter`** classes | All question figures are generated and drawn programmatically, so there are no image assets and the app works offline |
| Session history | **Hive** (local database) | Stores the last 30 finished sessions on the device |
| Settings and bias weights | **shared_preferences** | Small key-value store: last setup (`last_setup_*`), topic weights (`bias_weights_*`) |
| Charts | **fl_chart** | Score and time charts on result screens |
| Fonts | **google_fonts** (Lexend for the app); letter questions use Roboto | Readability for children |
| PDF papers | **pdf** + **printing** packages | Builds the A4 PDF and opens Android's print/share dialog |
| State management | Plain `setState` | The app is small enough not to need a state library |
| Android build | Gradle 8.14.3, Android Gradle Plugin 8.13.0, Kotlin 2.2.20, Java 17 | Pinned versions that work together (see 9.6) |
| CI / releases | **GitHub Actions** (`.github/workflows/beta-release.yml`) | Builds and publishes the APK when a beta tag is pushed |

### 4.2 Screens and how a child moves through them

```
SessionConfigScreen (home: topics, level, length, timer, language, Print paper button)
   ├─► QuizScreen (one question at a time, timer, bias weights updated after every answer)
   │      └─► SessionSummaryScreen (score, charts)
   │             ├─► SessionReviewScreen (every question with right/wrong highlighted)
   │             └─► StudentResultScreen / SessionDetailScreen (per-topic report)
   ├─► SessionHistoryScreen (last 30 sessions) ─► SessionDetailScreen
   └─► PrintPaperScreen (number of students, paper language, make PDF)
```

Session lengths: 5, 10, 15, 20, 25, 30, 40 or 50 questions. Timer per question: 30 s, 1 min, 2 min or unlimited.

> **Important:** Read `docs/hard-mode-history.md` before changing `hard_question_generator.dart` or `sandia_painter.dart`. It records about 25 bugs found and fixed there; several look like new reports but had different causes.

### 4.3 Code map (`lib/`)

About 19,000 lines of Dart. The biggest and most important files are in `engine/`.

| Folder / file | What it holds |
|---|---|
| `main.dart` | App entry: starts Hive, sets the Lexend theme, opens the config screen |
| `config/localization.dart` | Every on-screen string in English, Marathi and Hindi (`AppLocale.s('key')`); `AppLocale.topicName` gives one name per topic for every screen |
| `config/version.dart` | Version and build number shown in the app (kept in step with `pubspec.yaml` by the release hook) |
| `data/` | Hive storage of finished sessions (`hive_service.dart`, `session_record.dart`; `.g.dart` is generated code) |
| `engine/question_generator.dart` | **The router.** `QuestionGenerator.generate(topic, difficulty:)` decides which generator makes each question; it also holds the original ("classic") generators for every topic and stops repeats within a session |
| `engine/hard_question_generator.dart` | The **Sandia engine**: multi-layer shaded matrix questions for Odd Man, Figure Match, Pattern (and Series/Analogy at Hard). Read `docs/hard-mode-history.md` before changing it |
| `engine/exam_style_generator.dart` | Exam-style items copied from real JNVST papers: Geo grid cut, Embedded line drawings, 2x2 Pattern quarters, Figure Match, mirror-image Odd Man, Punch Hole fold sequences, Mirror line figures |
| `engine/series_generator.dart`, `analogy_generator.dart` | Exam-style Figure Series and Analogy rule families |
| `engine/space_vis_generator.dart` | Space Visualisation (which figure the pieces make) |
| `engine/book_generator.dart` | Types from the Arihant JNV guide book: letter-word odd man, symbol counting, shifting letters, symbols round a box, paper folding |
| `engine/line_figure.dart` | **`LineFig`**: figures as lines on a small grid. Exact turning, flipping, "is this hidden inside that", and `key` ("do these two look the same as drawn") |
| `engine/test_paper.dart` | Builds a 40-question printed paper and per-student shuffled sets |
| `engine/difficulty.dart` | `Difficulty { easy, medium, hard }` |
| `painters/` | Code that draws each figure type: `line_figure_painter` (LineFig), `sandia_painter` (shaded matrices), `figure_painter` (classic shapes), `mirror_text_painter`, `punch_painter`, `geo_piece_path` |
| `widgets/question_renderer.dart` | Draws the question area for each puzzle type |
| `widgets/option_renderer.dart` | Draws each answer option; picks the painter from the option's `type` |
| `paper/paper_pages.dart`, `paper_pdf.dart` | Layout and PDF output of printed papers |
| `screens/` | The screens listed in 4.2 |

### 4.4 How a question is stored

Every question is a `ReasoningQuestion`: a topic, a type name (e.g. `geo_grid_cut`), a `puzzle` map describing the question figure, four `options` maps, and `correctIndex`. Maps are plain data, so they can be saved, compared, tested and drawn anywhere. The `type` inside each map tells the renderer which painter to use:

| `type` | Drawn by | Used for |
|---|---|---|
| `line_fig` | `LineFigurePainter` | Most exam-style figures (grid of lines, black half-cells, dots, arrows, hatching, arcs, symbols) |
| `sandia_cell` | `SandiaPainter` | Shaded multi-shape matrix cells (Hard engine) |
| (no type: `shape`, `rotation`, `dots`...) | `EnhancedFigurePainter` | Classic single-shape figures |
| `mirror_text` | `EnhancedMirrorTextPainter` / `MirrorTextPainter` | Letters, digits, clocks |
| `punch_hole` | `PunchPainter` | Punched paper |
| `geo_piece` | geometry piece painters | Classic Geo Completion |

---

## 5. How questions are made

### 5.1 The routing rule

`QuestionGenerator.generate(topic, difficulty:)` picks a generator by topic and level, often by a weighted coin toss. For example, Medium Figure Series is about 60% exam-style series, 20% guide-book series and 20% classic series. The full mix is in `_generateMediumRaw` (Medium) and `_generateRaw` (Easy and Hard) in `question_generator.dart`.

### 5.2 Design rules every generator follows

These rules came out of real bug reports (section 9). Keep them when adding questions.

1. **Add, never replace.** New generators are added to a topic's mix; the old ones stay. The mentors asked for variety, and old generators are tested.
2. **One right answer, by construction and by test.** Every generator works out the answer from its own rule, and a test re-solves the question from the drawings alone and checks exactly one option fits.
3. **"Looks the same" means as drawn.** Two options are different only if a person can see the difference. `LineFig.key` ignores lines hidden on a black edge or the frame and dots hidden on a line; the Sandia engine renders options on a 64x64 grid and requires 5% of the cell to change by 50/255.
4. **Nothing hidden.** No figure may contain a detail you can't see (e.g. a dot under a black triangle) - `LineFig.hasHiddenDetail`.
5. **Balanced wrong options.** The four options form a balanced set (e.g. {right change, wrong change} x {right count, wrong count}) so the answer is never "the odd one out" of the options or "the one in the middle". Tests check no option is uniquely central.
6. **No flipped copies where a flip is legal.** A cut-out Geo piece can be turned over, so no option may be the answer flipped. An Embedded wrong option may not hide the shape in any orientation.
7. **Level meaning.** Easy changes one thing per question (grades 2-3). Medium is a true midpoint, never Easy or Hard material. Hard is exam level.

### 5.3 Adding a new question type (recipe)

1. Write a generator that returns `ReasoningQuestion?` (return `null` if a random draw fails a check; the router falls back).
2. Use an existing figure `type` (usually `line_fig`) so no new painter is needed.
3. Shuffle the options and record `correctIndex`.
4. Add it to the router at a small share for the right levels.
5. Write a test that solves the question from its data and checks exactly one option is right (see `test/book_generator_test.dart` for small examples).
6. Run `flutter test`; the cross-topic tests (`no_hidden_detail_test`, `question_generator_test`, visual tests) will also check it.

---

## 6. The printed test paper

Coordinators open **Print paper** on the config screen, choose the number of students (1-60) and the **paper language** (English, Marathi, or both), and press **Make PDF**. Android's print/share dialog opens with the PDF.

| Feature | How it works |
|---|---|
| Content | 10 parts x 4 questions in JNVST order (`TestPaper.partIds`) |
| Difficulty per part | `TestPaper.partLevels`: mostly 1 Easy, 2 Medium, 1 Hard; Odd Man, Figure Match, Geo have no Easy; Analogy 3 Medium + 1 Hard (mentors' request) |
| Per-student sets | Same 40 questions, shuffled within equal-difficulty runs, options shuffled; teacher key on the last page |
| Layout | A4, 20 questions a side in two columns, exam style: single-figure questions on one line, series/analogy/folding on two lines. Figures 10-14 mm, 3x3 grids 1.4x bigger |
| Drawing | Pages are drawn by the app's own painters at app size (80 px) then scaled down, so lines keep their proportions; converted to grayscale and compressed (`_grayPage`, about 0.3 s a page) |
| Languages | `paperText(langs, key)`; with both languages the directions print English then Marathi |

`paper_pdf.dart` uses one internal file of the `pdf` package (`package:pdf/src/pdf/format/num.dart`) to add pre-compressed images. If `pdf` is upgraded past 3.12 and this breaks, see 10.5.

---

## 7. How we work: testing, feedback, releases

### 7.1 Testing method

The project relies on automated tests because a person can't check thousands of generated questions by eye. There are 31 test files and 247 tests. The main kinds:

| Kind | Example files | What they prove |
|---|---|---|
| Solve-from-data | `series_test`, `analogy_test`, `space_vis_test`, `book_generator_test`, `exam_style_test` | Hundreds of questions per type; each is solved from its drawings and exactly one option is right |
| Level properties | `easy_level_test`, `medium_level_test` | Easy changes one thing; Medium is between Easy and Hard |
| Look-alike / visibility | `line_figure_key_test`, `no_hidden_detail_test`, `question_generator_visual_dedup_test`, `hard_generator_visual_test`, `sandia_outline_test` | No two options look the same when drawn; nothing hidden |
| Engine diagnostics | `hard_generator_diagnostics_test` | Sandia engine: no crashes, no duplicates, no tiny features |
| Screens | `quiz_layout_test`, `multi_topic_test`, `report_screens_test`, `print_paper_screen_test` | Screens build and behave at phone size |
| Paper | `paper_pdf_test`, `test_paper_test`, `mentor_paper_review_test` | Every page fits A4 in all languages; PDF page counts; mentors' review points |

> **Tip:** Every bug fix starts with a test that fails; the fix then makes it pass. This rule kept the same bugs from coming back.

### 7.2 Feedback loop

1. Mentors test a beta on their phones and log each issue in the **Notion tracker** (Name, Bug/Feature, Status, screenshots in the comments).
2. The developer reads the tracker (the developer never edits it - the mentors own it), reproduces the problem with a test, fixes it, and reports back.
3. Fixes are released as the next beta; the mentors set the item to **Fixed** after checking.

Printed papers were reviewed the same way, by WhatsApp messages and PDF annotations from the mentors.

### 7.3 Git branches

| Branch | Role |
|---|---|
| `master` | Release line. Every beta is tagged on master. |
| `hard-mode-exam-style` | Where all work since September 2026 was done; merged into master for each release |
| `session-rework`, `generator-rework`, `generator-revamp`, ... | Older feature branches, already merged |
| `release-check` | Local-only branch used to test the beta 8 merge; can be deleted |

Work on a branch, run `flutter analyze` and `flutter test`, then merge into master for a release.

### 7.4 Making a beta release

Version format: `pubspec.yaml` `version: 1.0.0-beta.N+N`, tag `v1.0.0-beta.N`. `lib/config/version.dart` must match (`preRelease = 'beta.N'`, `buildNumber = N`).

1. Merge the work branch into `master`; resolve conflicts; run `flutter analyze` and `flutter test` on the result.
2. Push master: `git push origin master`.
3. The **pre-push hook** (`tools/git-hooks/pre-push`) asks "cut a new beta?" - in a dialog box on Windows, a zenity dialog on a Linux desktop, or as a question in the terminal otherwise. Click **Yes** and accept the suggested tag. It bumps both version files, commits, tags and pushes the tag. (If you made the version commit and tag yourself, click **No**.)
4. Pushing the tag starts **GitHub Actions**: it checks the tag matches `pubspec.yaml`, runs analyze and tests, builds the APK and AAB, and publishes them as the **Latest** release (about 8 minutes). Watch it under the repo's **Actions** tab or with `gh run list`.
5. Send testers the release link. They install `app-release.apk` (see 11.3 about signing).

> **Important:** Never delete or reuse a published tag. If something is wrong, fix it and release the next beta number (`docs/release_beta.md`).

---

## 8. History: how the project grew

| When (2026) | Milestone |
|---|---|
| Jan-Mar | Project started; quiz engine, sessions, review screen. Switched from static image questions to **generated questions** drawn by code. |
| Mar-Apr | Intelligent Bias, weak-area practice, Hive history, Marathi then Hindi, session detail and student result screens |
| May | First betas (beta 1-3); automated version tracking; Mirror Text overhaul; Java/Gradle CI fixes |
| Jul-Aug | **Hard Mode** with the Sandia matrix engine (shaded multi-layer figures based on the Sandia Generated Matrix Tool); beta 4; pre-push release hook |
| Sep | Exam-style questions from real JNVST papers for every topic; Space Visualisation topic; LineFig drawing parts (arrows, hatching, arcs, symbols); multi-topic sessions; **Medium** level; beta 5-6 |
| Oct | Medium reworked as a true midpoint; **printed test paper** (A4 PDF, per-student sets); guide-book question types; English/Marathi papers; many fixes from mentors' reviews; beta 7 |
| 3 Nov | **Beta 8**: everything above plus all tracker fixes |

The full list of commits is in `git log`; Hard Mode decisions are written up in detail in `docs/hard-mode-history.md`; `CHANGELOG.md` covers the early betas.

---

## 9. Problems we hit and how we fixed them

Grouped by area. For each: what went wrong, the real cause, and the fix. The same kinds of problems tend to come back, so section 10 turns these into a checklist.

### 9.1 Questions with two right answers or look-alike options

The most common class of bug. It almost always had the same shape: two options that differ in the data but **look** the same on screen.

| Problem | Cause | Fix |
|---|---|---|
| Hard Pattern/Odd Man options came in "two identical pairs" | Wrong options are built from two changes in every combination; if one change was invisible, options paired up | Every Sandia question is rendered on a 64x64 grid and rejected if any two options differ too little (`_hasNearDuplicateOptions`, hard-mode-history #14-17) |
| Shaded options still looked alike to testers (Oct 2026) | The visibility bar (2% of the cell, 30/255) let dark-on-dark changes through | Raised to 5% of the cell and 50/255 (#25). Near-twin pairs in Figure Match Hard went from 32/84 to 0 |
| Pattern 2x2 options A and C identical | A changed line ran exactly along a black triangle's edge, so it couldn't be seen | `LineFig.key` treats lines on black edges and on the frame as invisible |
| Figure Match duplicates (tracker, Oct) | A dot drawn on a diagonal line or a black half-cell disappears | `key` ignores hidden dots; generators reject any figure with a hidden dot (`hasHiddenDetail`) |
| Geo Completion: two pieces fit (mentors, Oct) | A wrong piece was the answer **flipped over**; a paper piece can be turned over | Pieces are compared up to turning **and** flipping (`flipClass`); wrong pieces are one-cell changes only |
| Embedded Figure: a wrong option "contained" the shape (testers) | Wrong options hid the shape turned or flipped, which children read as "it's there" | Wrong options hide a near-miss shape (one stroke moved) and never the shape in any orientation |
| 2x2 Pattern: options differ only by a dot | The "small change" moved a dot one cell | The wrong option's change is the black half-cell flipping instead |
| Odd Man (Sandia) rotations identical for rectangle/diamond | Shapes symmetric under 180° look the same at 0° and 180° | Comparison knows each shape's symmetry; orientations spread over 180° |
| Series/Analogy duplicates from a cross background | The cross looks the same every 90° | Removed symmetric backgrounds from the pools |

### 9.2 Questions that were too hard, too easy or unclear

| Problem | Cause | Fix |
|---|---|---|
| Easy questions too hard for grades 2-3 | Easy reused Hard-style multi-change rules | Easy changes one thing per question in every topic; tests pin it |
| Medium was "Easy or Hard by coin toss" | First Medium version mixed the two | Medium got its own router with lite settings of each generator |
| Mentors: paper questions 1-6, 8, 17, 21-23 too easy (facilitators also sit it) | Paper used Easy/Easy/Medium/Medium | Per-topic mix with Hard questions |
| Series showed 4 figures before the "?" | One series type (`series_alt_dual`) used 4 frames | Every series shows 3 figures then "?" |
| Punch Hole folds unclear on paper | No direction shown | Fold arrows on every fold panel |
| Mirror Text level mismatch (tracker) | One length for every level | Easy 1-2 characters, Medium 2-3, Hard 4 |
| Session title said "Mirror image" for both mirror topics (tracker) | Separate, older title strings | One `AppLocale.topicName` for config and session |

### 9.3 Drawing problems

| Problem | Cause | Fix |
|---|---|---|
| Question figure looked different from its own correct option | Question area used an older painter | The question area draws with the same code as the options |
| Detail on filled shapes vanished | Dark details on dark fills | White details with a navy outline |
| White diamond on a black rectangle invisible | Dark outline on dark fill | Outlines drawn after a dark shape get a white edge |
| Mirror Text distorted / numbers mirrored wrongly | Text mirrored on the canvas directly | Text drawn to a picture first, then mirrored |
| Letters showed as black blocks in test renders | Flutter tests use a block font unless a font is named | Letter painters name Roboto (Android's default) |
| L shape's mirror and turn looked alike | Foot and upright too similar in length | Foot 1.1 vs upright 1.7 units; pixel test |

### 9.4 Printed paper problems

| Problem | Cause | Fix |
|---|---|---|
| Too few questions per page (coordinator wanted 20 a side) | One question per row | Two columns, exam style, flow down then across |
| Figures dense on paper (lines swamp details) | Painters use fixed 2-3 px lines tuned for 80 px figures; paper boxes are 13 mm | Draw at 80 px and scale down; no inner Sandia frame in print |
| Dots touching the box | Classic figures put dots near the bottom edge | Small margin around classic figures in print |
| PDF slow (1.3-2 s a page) | PNG encode/decode in Dart | Grayscale + zlib compression directly (0.3 s a page) |
| Marathi wanted | English only | Language picker: English, Marathi, both |
| Shading may vanish on a photocopier | Light greys become white in pure black/white copies | Not changed yet - see 11.4 |

### 9.5 Build, CI and tooling problems

| Problem | Cause | Fix |
|---|---|---|
| CI failed with a Java toolchain error | Gradle daemon JVM settings pointed at a local Java | CI uses Temurin 17 and deletes `gradle-daemon-jvm.properties` before building |
| Gradle / Android Gradle Plugin mismatch | Upgrading Gradle to 9.x broke the Flutter Gradle plugin | Pinned Gradle 8.14.3 with AGP 8.13.0 (Flutter doesn't support AGP 9 yet) |
| Beta 6 CI failed | Tests depended on a Windows-only font | Tests no longer load Windows fonts |
| pubspec version and in-app version drifted | Two files updated by hand | The pre-push hook updates both together |
| Hook suggested the wrong next beta | It didn't notice an untagged version | Fixed in the hook (Sep) |
| Release hook blocked pushes on Linux | It called Windows-only `powershell.exe` | The hook picks Windows dialogs, zenity, or terminal prompts automatically (Nov) |
| Debug and release app couldn't both be installed | Same package name | Debug builds use the `.debug` suffix |
| Releases didn't show on the GitHub repo page | Published as pre-releases | Published as Latest releases |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` on the phone | Release builds are signed with a CI-generated debug key that changes each run | Uninstall then install; permanent fix in 11.3 |

### 9.6 Process problems

| Problem | Cause | Fix |
|---|---|---|
| A whole feature (Medium) had to be reverted before beta 6, then restored for beta 7 | It wasn't ready when the release was cut | Release only from a branch that passes all tests; trial-merge first |
| A history doc once described fixes that weren't in the code | Notes written from memory | Every fix now has a test; trust tests over notes |
| Testers kept reporting bugs that were already fixed | Their phones ran the old beta | Release more often; check which beta a screenshot comes from |

---

## 10. Troubleshooting future problems

### 10.1 A tester reports "two options look the same" or "two answers fit"

1. **Find the build.** Ask which beta they run (the version badge in the app shows it). If it's older than the latest, ask them to update first.
2. **Find the generator.** The topic is in the screenshot header; the question type tells you the file (section 4.3). Run a quick script or test that generates that topic and level and prints `q.type` to narrow it down.
3. **Reproduce with a test.** Generate a few hundred questions of that type and check the property that failed (e.g. "no two options have the same `key`", "only one option embeds the target").
4. **Look for the usual causes:** something hidden (on a line, a black area or the frame); a flip or turn being legal for the solver; a shape that is symmetric so a turn changes nothing; a visibility bar too low.
5. **Fix in the generator** (reject such draws or change the wrong-option rule), not in the painter, unless the drawing itself is wrong.
6. Run the full test suite, install a debug build, check on the phone.

### 10.2 The phone isn't found

| Symptom | Fix |
|---|---|
| `adb devices` is empty | Turn **Wireless debugging** back on (it switches off on sleep / network change), or plug in the cable |
| "more than one device/emulator" | The phone is listed twice; use `adb -s <one-of-the-names> ...` |
| "unauthorized" | Accept the prompt on the phone; if none, revoke USB debugging authorisations in Developer options and reconnect |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | The installed app has a different signature: `adb uninstall <package>` then install (this deletes that app's local history) |

### 10.3 Build fails

| Symptom | Fix |
|---|---|
| Dependency errors after `git pull` | `flutter clean` then `flutter pub get` |
| Gradle/AGP version errors | Keep Gradle 8.14.3 and AGP 8.13.0 (`android/gradle/wrapper/gradle-wrapper.properties`, `android/settings.gradle.kts`); don't upgrade AGP to 9.x until Flutter supports it |
| Java errors | Use Java 17 or newer; `flutter doctor -v` shows which one Flutter uses. To point Flutter at a specific JDK: `flutter config --jdk-dir "<path to JDK>"` |
| CI fails at "Validate tag" | Tag and `pubspec.yaml` version differ; fix `pubspec.yaml`, release the next beta number |
| CI fails at "Test" but tests pass locally | Look for tests depending on Windows paths or fonts; tests must not use `C:\...` |

### 10.4 Tests fail after a change

- Read the test's comment at the top of the file - it says what property it protects and often which report it came from.
- If your change deliberately changes behaviour (e.g. a new question type in a mix), update the test's expectations and say why in the comment. If not, the test caught a real bug.
- A sudden "too many failed draws" means a generator now rejects most random draws; loosen the new check or add retries.

### 10.5 Library upgrades

- Upgrade one package at a time (`flutter pub upgrade <name>`), then run all tests.
- The `pdf` package is used through one internal file in `lib/paper/paper_pdf.dart`; after upgrading `pdf`, run `flutter test test/paper_pdf_test.dart`. If it fails, replace `_grayPage` with `pw.MemoryImage` of a PNG (slower but uses only the public API).

### 10.6 Printing problems

| Symptom | Fix |
|---|---|
| Text overflow / page doesn't fit | Run `flutter test test/paper_pdf_test.dart` (checks all languages); shorten the string in `localization.dart` or adjust `_dirHeight` |
| Figures too small | Fewer two-line questions per side, or fewer questions per side (`questionsPerSide`) |
| Shading lost on photocopies | See 11.4 |

---

## 11. Access, accounts and loose ends

### 11.1 Accounts to transfer

| Item | Held by now | Action |
|---|---|---|
| GitHub repository `harikn2003/mental-ability-app` | The developer's GitHub account | Add the new owner as a collaborator with Admin, or transfer the repository to an organisation account |
| GitHub Actions | Runs in the repository | No secrets are configured at present |
| Notion tracker | The mentors' Notion workspace | Ask the workspace owner to share the database with the new owner |
| Test phone | The developer | Hand over or set up a new one (section 2.6) |

> **Note:** No passwords, keys or tokens are stored in the repository.

### 11.2 Local files that are not in the repository

The project folder on the developer's PC also has these, which are **not** part of the code and should not be committed: `android.zip`, `lib.zip`, `commit-diff.txt`, the JNV PDFs in `docs/` and `docs/pyq/`, and assistant folders (`.claude/`, `.agents/`, `AGENTS.md`). The JNV guide books and model papers in `docs/` were used as references for question styles; hand them over separately if needed.

### 11.3 Must fix: release signing (high priority)

`android/app/build.gradle.kts` signs **release** builds with the **debug** key, and CI creates a new debug key on every run. Result: every new beta has a different signature, so Android refuses to update the old one (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) and testers must uninstall first, which **deletes their session history**. This also blocks any Play Store release.

Fix (about 1 hour):

1. Create a release keystore once (`keytool -genkey -v -keystore nplusprep-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nplusprep`).
2. Add a `release` signing config in `android/app/build.gradle.kts` reading the keystore path and passwords from `android/key.properties` (not committed).
3. In GitHub: Settings → Secrets → add the keystore (base64) and passwords; in `beta-release.yml`, decode it and write `key.properties` before building.
4. The first beta with the new key still needs one uninstall; after that, updates install over the top.

> **Warning:** Keep the keystore and its passwords safe and backed up in two places. If it is lost, the app can never again be updated under the same name.

### 11.4 Open items

| Item | Detail | Size |
|---|---|---|
| Release signing | 11.3 | ~1 h |
| Photocopy-safe papers | Light greys vanish on pure black/white photocopies. Option: print grey levels as dot / line / cross-hatch patterns | ~30 min |
| Hard shaded Pattern | 13/84 questions still have an option pair differing only by one thin extra outline shape; if mentors flag it, stop overlapping white outline shapes in Hard | ~45 min |
| CI notices | GitHub warns that Node 20 actions and `actions/setup-java@v4` are deprecated; bump to `setup-java@v5` and current action versions | ~15 min |
| Exam-format mock test | 40 questions in exam order, 60 minutes, per-part score; deferred until the app is stable | 1-2 days |
| Answer explanations | Requested earlier in the tracker; not started | 1-2 days |
| Notion statuses | 2 bugs (Geo ambiguity, Reducing ambiguity) and 3 features (Mirror 3 modes, Medium section, Level setting) are fixed in beta 8; mentors to mark them Fixed | - |
| Old local branches | `release-check`, `release-prep`, `ui-mock`, ... can be deleted after checking they're merged | - |

### 11.5 Key documents in the repository

| File | Contents |
|---|---|
| `docs/HANDOVER.md` | This document |
| `CLAUDE.md` / `README.md` | Short architecture notes (README's feature list predates Hindi, Medium and printing) |
| `docs/hard-mode-history.md` | Every Hard Mode bug and decision in detail (#1-#25); read before changing `hard_question_generator.dart` or `sandia_painter.dart` |
| `docs/release_beta.md` | Manual release checklist |
| `docs/phone_preview.md` | Preview on a phone through the browser |
| `CHANGELOG.md` | Early beta notes |

---

## 12. Glossary

| Term | Meaning |
|---|---|
| **JNVST** | Jawahar Navodaya Vidyalaya Selection Test; its Mental Ability Test is what the app trains for |
| **Topic / category** | One of the 11 question kinds (internal names like `odd_man`, `geo_completion`) |
| **Generator** | Code that makes a question of one kind |
| **Distractor** | A wrong option |
| **Balanced answer set** | Wrong options built so the right answer can't be spotted by elimination |
| **Sandia engine** | The Hard Mode generator for shaded multi-layer matrices, modelled on the Sandia Generated Matrix Tool |
| **LineFig** | Our figure format: lines and marks on a small grid, which makes "same", "turned", "flipped" and "hidden inside" exact |
| **Classic generators** | The original generators from early 2026, kept in the mix |
| **Exam-style generators** | Generators copied from real JNVST paper items |
| **Intelligent Bias** | Per-topic weights that make weak topics come up more often |
| **Beta** | A test release published on GitHub for the mentors and testers |
| **Debug / release build** | Debug: for development, installs as `...debug`; release: what testers install |
| **adb** | Android Debug Bridge, the tool that talks to the phone from the PC |
| **CI** | Continuous Integration: GitHub Actions building and publishing releases |
