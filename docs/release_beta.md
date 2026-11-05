# Beta Release

One command, run from `master` when you want a release:

```bash
dart run tool/release.dart
```

1. Merge your work into `master` (`git checkout master`, `git merge <branch>`).
2. Run the command. It asks for the tag: press Enter for the next beta, or type
   one (`vX.Y.Z-beta.N`, e.g. `v1.1.0-beta.1`).
3. Check what it shows (version, build number, codename, commits going out) and
   answer `y`.
4. It runs `flutter analyze` and `flutter test`, updates `pubspec.yaml` and
   `lib/config/version.dart` together, commits, tags, and pushes master and the
   tag in one atomic push.
5. GitHub Actions builds the APK and AAB and publishes the **Latest** release,
   titled e.g. `v1.0.0-beta.10 (Date)` (about 8 minutes). The command prints
   the links.

| Option | What it does |
|---|---|
| `--tag v1.0.0-beta.12` | Use this tag without asking |
| `--dry-run` | Show what would happen; change nothing |
| `--skip-tests` | Skip analyze/test locally (CI still runs them) |
| `--yes` | No questions: the `--tag` given, or the next beta |
| `--print-codename` | Print the current build's codename (used by CI) |

## Rules

- Version format: `pubspec.yaml` `version: 1.0.0-beta.N+B`, tag `v1.0.0-beta.N`.
  The build number `B` goes up by one every release (Android needs it to rise).
- The codename comes from the build number (`AppVersion.buildCodenames` in
  `lib/config/version.dart`), so it moves on by itself. To skip a name, comment
  it out in that list.
- Never delete or reuse a published tag. If something is wrong, fix it and
  release the next beta number.
- CI checks the tag matches `pubspec.yaml`; `test/release_tool_test.dart`
  checks the two version files agree.

## Older clones

Before beta 10 a pre-push hook offered to cut a release on every push to
master. It has been removed. If your clone still has it switched on, run once:

```bash
git config --unset core.hooksPath
```
